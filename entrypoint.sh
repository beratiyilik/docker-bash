#!/bin/bash
# entrypoint.sh — container initialization script
#
# Responsibilities:
#   1. Log environment info (user, host, kernel, cwd)
#   2. Install the custom .bashrc into the user's home directory
#   3. Hand off to CMD (or /bin/bash if none provided)
#
# Usage (Dockerfile):
#   ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
#   CMD        ["/bin/bash"]
#
# Exit codes:
#   0  — clean exit (including signal-triggered shutdown)
#   1  — die() called on unrecoverable error
#
set -euo pipefail
# -e  exit immediately on non-zero return
# -u  treat unset variables as errors
# -o pipefail  pipelines fail on the first non-zero stage

###############################################################################
# LOGGING
###############################################################################

# 13-digit Unix epoch in milliseconds: %s = seconds, %3N = millisecond suffix.
timestamp() { date -u +"%s%3N"; }

# Internal log emitter.
# Usage: _emit [LEVEL] [printf-fmt] [args...]
# If LEVEL is empty the prefix is omitted (plain log line).
# stdout for log/info, stderr for warn/die.
_emit() {
    local lvl="${1:-}"; shift || true
    printf '[%s]%s ' "$(timestamp)" "${lvl:+ $lvl:}"
    # only call printf with a format string when arguments are present;
    # avoids interpreting an empty string as a format
    if (($#)); then
        printf "$@"
    fi
    printf '\n'
}

log()  { _emit ""      "$@"; }        # unleveled — startup/shutdown markers
info() { _emit "INFO"  "$@"; }        # normal operational messages
warn() { _emit "WARN"  "$@" >&2; }   # non-fatal; continues execution
die()  { _emit "ERROR" "$@" >&2; exit 1; }  # fatal; exits with code 1

###############################################################################
# SIGNAL HANDLING
###############################################################################

# Called by trap on SIGTERM, SIGINT, or SIGHUP.
# Logs the signal name and exits cleanly so Docker gets a zero exit code
# and does not escalate to SIGKILL after the stop timeout.
_cleanup() {
    local sig="${1:-TERM}"
    log "Received SIG%s, shutting down..." "$sig"
    exit 0
}

trap '_cleanup TERM' SIGTERM   # docker stop / kubernetes preStop
trap '_cleanup INT'  SIGINT    # Ctrl-C in interactive sessions
trap '_cleanup HUP'  SIGHUP    # terminal hangup / daemon reload signal

###############################################################################
# ENVIRONMENT INFO
###############################################################################

# Collect identity and context at startup.
# These are used for logging only — nothing here mutates state.
_user="$(whoami)"          # effective username (may differ from CONTAINER_USER)
_uid="$(id -u)"            # effective UID
_gid="$(id -g)"            # effective GID
_host="$(hostname)"        # container hostname (set via --hostname or Dockerfile)
_kern="$(uname -srm)"      # kernel name, release, machine architecture
_pwd="$PWD"                # working directory at entrypoint invocation
_home="${HOME:-}"          # user home; may be empty for certain uid mappings

info "Environment setup starting"
info "user : %s (uid=%s gid=%s)" "$_user" "$_uid" "$_gid"

# If CONTAINER_USER is set (injected via ENV in Dockerfile) but differs from
# the effective user, surface that — useful when running with --user override.
if [[ -n "${CONTAINER_USER:-}" && "$_user" != "$CONTAINER_USER" ]]; then
    info "as   : %s (CONTAINER_USER)" "$CONTAINER_USER"
fi

info "host : %s" "$_host"
info "os   : %s" "$_kern"
info "pwd  : %s" "$_pwd"
info "home : %s" "${_home:-?}"   # '?' displayed when HOME is unset

###############################################################################
# BASHRC MANAGEMENT
###############################################################################

# Source location for container resource files copied in during image build.
# Dockerfile: COPY src/ /var/tmp/container_resources/
RESOURCES_DIR="/var/tmp/container_resources"
CUSTOM_BASHRC="${RESOURCES_DIR}/.bashrc"

# apply_bashrc <target_home>
#
# Installs the custom .bashrc from RESOURCES_DIR into <target_home>/.bashrc.
# If an existing .bashrc is present it is backed up to /tmp before overwrite.
# Returns 1 (non-fatal) on any precondition failure; caller continues.
apply_bashrc() {
    local target_home="$1"

    # Guard: HOME may be unset or empty for uid mappings without a passwd entry.
    if [[ -z "$target_home" ]]; then
        warn "apply_bashrc: target_home is empty, skipping"
        return 1
    fi

    # Guard: the directory must exist before we write into it.
    if [[ ! -d "$target_home" ]]; then
        warn "apply_bashrc: directory does not exist: %s" "$target_home"
        return 1
    fi

    local bashrc_path="${target_home}/.bashrc"
    # Backup filename includes timestamp (ms epoch) + PID to survive multiple
    # rapid restarts without collisions (unlikely but cheap to prevent).
    local backup_path="/tmp/.bashrc.backup.$(timestamp)_$$"

    # Back up any pre-existing .bashrc so the original can be restored if needed.
    if [[ -f "$bashrc_path" ]]; then
        cp "$bashrc_path" "$backup_path" \
            || { warn "Failed to back up %s" "$bashrc_path"; return 1; }
        info "Backed up .bashrc to %s" "$backup_path"
    fi

    # Guard: the custom .bashrc must have been placed by COPY in the Dockerfile.
    # Missing file is a build error, not a runtime one — warn but don't die so
    # the container still starts with the default shell.
    if [[ ! -f "$CUSTOM_BASHRC" ]]; then
        warn "Custom .bashrc not found at %s, skipping" "$CUSTOM_BASHRC"
        return 1
    fi

    cp "$CUSTOM_BASHRC" "$bashrc_path" \
        || { warn "Failed to apply .bashrc to %s" "$bashrc_path"; return 1; }
    info "Applied custom .bashrc to %s" "$bashrc_path"
}

apply_bashrc "$_home"

###############################################################################
# BASHIFY INSTALLATION
###############################################################################

# BASHIFY_DIR is the system-wide install dir, exported once via ENV in the
# Dockerfile (single source of truth). BASHIFY_LIB is the file we source from it.
BASHIFY_LIB="${BASHIFY_DIR}/bashify.bash"

# apply_bashify <target_home>
#
# Appends a source line for bashify.bash into <target_home>/.bashrc.
# Idempotent: skips if the source line already exists.
# Returns 1 (non-fatal) on any precondition failure; caller continues.
apply_bashify() {
    local target_home="$1"
    local bashrc_path="${target_home}/.bashrc"
    local source_line="[[ -f \"${BASHIFY_LIB}\" ]] && source \"${BASHIFY_LIB}\""

    # Guard: library must exist at the expected path (placed by Dockerfile).
    if [[ ! -f "$BASHIFY_LIB" ]]; then
        warn "bashify.bash not found at %s, skipping" "$BASHIFY_LIB"
        return 1
    fi

    # Guard: .bashrc must exist before we can append to it.
    if [[ ! -f "$bashrc_path" ]]; then
        warn "apply_bashify: .bashrc not found at %s, skipping" "$bashrc_path"
        return 1
    fi

    # Idempotency check: do not append if bashify is already sourced. Match on
    # the stable "bashify.bash" substring so it catches the custom .bashrc form
    # (which sources via $BASHIFY_DIR) as well as a previously appended line.
    if grep -qF "bashify.bash" "$bashrc_path" 2>/dev/null; then
        info "bashify already enabled in %s, skipping" "$bashrc_path"
        return 0
    fi

    printf '\n# load bashify prompt library\n%s\n' "$source_line" >> "$bashrc_path" \
        || { warn "Failed to append bashify source line to %s" "$bashrc_path"; return 1; }
    info "Enabled bashify in %s" "$bashrc_path"
}

apply_bashify "$_home"

# BASHIFY_CONFIG is the starter config placed by COPY in the Dockerfile.
# bashify resolves config from BASHIFY_USER_CONFIG, then
# ${XDG_CONFIG_HOME:-~/.config}/bashify/bashifyrc, then ~/.bashifyrc.
BASHIFY_CONFIG="${RESOURCES_DIR}/bashifyrc"

# apply_bashifyrc <target_home>
#
# Seeds the starter bashify config into the XDG location for <target_home>.
# Never clobbers an existing config (XDG or legacy ~/.bashifyrc) so user edits
# survive container restarts. Returns 1 (non-fatal) on precondition failure.
apply_bashifyrc() {
    local target_home="$1"
    local config_dir="${target_home}/.config/bashify"
    local config_path="${config_dir}/bashifyrc"
    local legacy_path="${target_home}/.bashifyrc"

    # Guard: HOME may be unset for uid mappings without a passwd entry.
    if [[ -z "$target_home" || ! -d "$target_home" ]]; then
        warn "apply_bashifyrc: invalid home %s, skipping" "$target_home"
        return 1
    fi

    # Guard: the starter config must have been placed by COPY in the Dockerfile.
    if [[ ! -f "$BASHIFY_CONFIG" ]]; then
        warn "bashify config not found at %s, skipping" "$BASHIFY_CONFIG"
        return 1
    fi

    # Respect any config the user already has, in either supported location.
    if [[ -f "$config_path" ]]; then
        info "bashify config already present at %s, skipping" "$config_path"
        return 0
    fi
    if [[ -f "$legacy_path" ]]; then
        info "legacy bashify config present at %s, leaving as-is" "$legacy_path"
        return 0
    fi

    mkdir -p "$config_dir" \
        || { warn "Failed to create %s" "$config_dir"; return 1; }
    cp "$BASHIFY_CONFIG" "$config_path" \
        || { warn "Failed to seed bashify config at %s" "$config_path"; return 1; }
    info "Seeded bashify config at %s" "$config_path"
}

apply_bashifyrc "$_home"

###############################################################################
# HANDOFF
###############################################################################

info "Environment setup complete. Ready for commands."

# Signal to the Docker health check that initialization has completed
# successfully. The HEALTHCHECK in the Dockerfile tests for this file:
#   CMD test -f /tmp/.container_ready || exit 1
# Written as late as possible so the flag reflects a fully initialized
# environment, not just a started process.
touch /tmp/.container_ready

# exec replaces this process with the target command so PID 1 is the actual
# workload, not bash — required for correct signal propagation in Docker.
#
# If no CMD arguments were passed (e.g. bare `docker run image`), fall back to
# an interactive bash shell rather than exiting immediately.
if [[ $# -eq 0 ]]; then
    exec /bin/bash
fi

exec "$@"