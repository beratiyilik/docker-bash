#!/bin/bash
set -euo pipefail

# minimal logging setup
timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_emit() {
  local lvl="${1:-}"; shift || true
  # prefix
  printf '[%s]%s ' "$(timestamp)" "${lvl:+ $lvl:}"
  # message: treat first arg as a printf format string, remaining as args
  if (($#)); then
    printf "$@"
  fi
  printf '\n'
}
log()  { _emit ""    "$@"; }
warn() { _emit "WARN" "$@" >&2; }
die()  { _emit "ERROR" "$@" >&2; exit 1; }

# function to handle signals gracefully
cleanup() {
    log "Received SIGTERM/SIGINT, cleaning up..."
    # add any cleanup tasks here if needed
    exit 0;
}

# trap signals
trap cleanup SIGTERM SIGINT SIGHUP

# gather some environment info
_user="$(whoami)"; _uid="$(id -u)"; _gid="$(id -g)"
_host="$(hostname)"; _kern="$(uname -srm)"
_pwd="$PWD"; _home="${HOME:-?}"

log "Environment setup starting"
log 'user: %s (%s:%s)' "$_user" "$_uid" "$_gid"
[[ -n "${CONTAINER_USER:-}" && "$_user" != "$CONTAINER_USER" ]] && log 'as:   %s (CONTAINER_USER)' "$CONTAINER_USER"
log 'host: %s' "$_host"
log 'os:   %s' "$_kern"
log 'pwd:  %s' "$_pwd"
log 'home: %s' "$_home"

RESOURCES_DIR="/var/tmp/container_resources"
CUSTOM_BASHRC="${RESOURCES_DIR}/.bashrc"

apply_bashrc() {
     local TARGET_HOME="$1"
     local BASHRC_PATH="${TARGET_HOME}/.bashrc"
     local BACKUP_PATH="/tmp/.bashrc.backup.$(date -u +%Y%m%d%H%M%S).$$"

     # if the original .bashrc exists, back it up
     if [[ -f "$BASHRC_PATH" ]]; then
         cp "$BASHRC_PATH" "$BACKUP_PATH"
         log "Backed up existing .bashrc to %s" "$BACKUP_PATH"
     fi

     # copy the custom .bashrc to the target home directory
     if [[ -f "$CUSTOM_BASHRC" ]]; then
         cp "$CUSTOM_BASHRC" "$BASHRC_PATH"
         log "Applied custom .bashrc to %s" "$BASHRC_PATH"
     else
         warn "Custom .bashrc not found at %s" "$CUSTOM_BASHRC"
     fi
}

apply_bashrc "$_home"

log "Environment setup complete. Ready for commands."

exec /bin/bash
