# husk — Ubuntu Development Container

A production-ready Docker development environment based on Ubuntu 26.04 with essential networking, development tools, and a feature-rich custom shell configuration powered by [Bashify](https://github.com/beratiyilik/bashify).

## Features

### Core System

- **Base**: Ubuntu 26.04 LTS
- **Locales**: Full UTF-8 support (`en_US.UTF-8`)
- **User Management**: Configurable non-root user with proper permissions
- **Security**: Non-root execution by default with shared group access

### Pre-installed Tools

- **System & Core**: `ca-certificates`, `locales`, `tzdata`, `coreutils`, `procps`
- **Shell & Editors**: `bash`, `bash-completion`, `nano`, `vim`, `less`
- **Networking**: `curl`, `wget`, `dnsutils`, `openssh-client`
- **Development**: `git`, `make`, `python3`, `python3-pip`
- **Utilities**: `grep`, `jq`, `unzip`, `eza` (modern ls replacement, installed from GitHub binary)

### Custom Shell Environment

- **Bashify Prompt**: Modular, Powerlevel10k-inspired prompt with git integration, right-aligned segments, and Docker-aware rendering
- **Smart Aliases**: Enhanced `ls` commands with `eza`, Docker shortcuts, safety aliases
- **Git Integration**: Branch name, staged/unstaged/untracked counts, stash, ahead/behind, conflict indicators
- **History Management**: 10,000-command in-memory history, 100,000-command file history with intelligent filtering
- **Container Detection**: Right prompt automatically disabled inside Docker containers and dumb terminals

## Project Structure

```text
.
├── Dockerfile            # Ubuntu 26.04 container definition
├── entrypoint.sh         # Environment setup and initialization script
├── docker-compose.yml    # Predefined run convention: output volume and init
├── Makefile              # build / shell / run / clean shortcuts
├── .dockerignore         # Keeps the build context minimal
├── LICENSE               # GPL v3 license
├── README.md             # This documentation
└── src/
    ├── .bashrc           # Custom Bash configuration with aliases and shell options
    └── bashifyrc         # Starter Bashify config, seeded to ~/.config/bashify/bashifyrc
```

### Working directory & outputs

`/workspace` is the canonical, host-mountable working directory (`WORKDIR_PATH`,
the single source of truth set in the [Dockerfile](Dockerfile) and surfaced as
an env var). Mount a host path or named volume there so work produced inside the
container survives it and is reachable from the host. Config/dotfiles stay in
`$HOME`.

> The prompt system [Bashify](https://github.com/beratiyilik/bashify) is no longer bundled here. It is fetched
> from upstream at build time and installed system-wide to `/usr/local/lib/bashify/`.

## Usage

### Recommended: Compose or Make

The [docker-compose.yml](docker-compose.yml) and [Makefile](Makefile) encode the
output volume and init process in one place, so you don't have to remember long
`docker run` invocations.

```bash
# Compose
docker compose build
docker compose run --rm dev      # interactive; outputs land in ./workspace

# Make
make build
make shell                       # throwaway interactive container
make run                         # long-lived named container (hours-to-weeks)
make start                       # re-attach to it later
make clean                       # remove it (keeps ./workspace)
```

Either path bind-mounts the host's `./workspace` to `/workspace` in the
container and runs a real init (`--init`) for correct signal handling and zombie
reaping.

### Quick Start (raw docker)

#### 1. Basic Build

```bash
docker build -t husk:ubuntu-26.04 .
```

#### 2. Advanced Build with Custom Arguments

```bash
docker build -t husk:ubuntu-26.04 \
  --build-arg VERSION=1.0.1 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg USERNAME=devuser \
  --build-arg UID=1001 \
  --build-arg GID=1001 \
  .
```

### Running Containers

#### 1. Simple Interactive Container

```bash
docker run -it --init --hostname devbox --name devbox husk:ubuntu-26.04
```

#### 2. Development Container with Volume Mount

```bash
docker run -it --init \
  --hostname $(hostname) \
  --name dev \
  -v "$(pwd)/workspace:/workspace" \
  husk:ubuntu-26.04
```

#### 3. Live Prompt Development (mount bashify for hot-reload)

Clone [bashify](https://github.com/beratiyilik/bashify) locally and mount its `bashify.bash` over the
installed one:

```bash
docker run -it \
  --hostname devbox \
  --name devbox \
  -v "/path/to/bashify/bashify.bash:/usr/local/lib/bashify/bashify.bash" \
  husk:ubuntu-26.04
```

Reload changes inside the container without rebuilding:

```bash
source /usr/local/lib/bashify/bashify.bash
```

#### 4. Background Development Server

```bash
docker run -d --init \
  --name dev-server \
  --hostname dev-server \
  -v "$(pwd)/workspace:/workspace" \
  -p 8080:8080 \
  husk:ubuntu-26.04 \
  tail -f /dev/null
```

### Container Management

```bash
# Start existing container
docker start -ai devbox

# Execute commands in running container
docker exec -it devbox bash

# Stop container
docker stop devbox

# Remove container
docker rm devbox

# View logs
docker logs -f devbox
```

## Build Arguments

| Argument | Default | Description |
| -------- | ------- | ----------- |
| `VERSION` | `1.0.0` | Image version for metadata |
| `VCS_REF` | `unknown` | Git commit hash for traceability |
| `BUILD_DATE` | `unknown` | Build timestamp (ISO 8601) |
| `USERNAME` | `devuser` | Primary user; running as root is strongly discouraged |
| `UID` | `1001` | User ID for the primary user |
| `GID` | `1001` | Group ID for the primary user |
| `SHARE_GID` | `2001` | Shared group ID for resource access |
| `WORKDIR_PATH` | `/workspace` | Canonical working/output dir; mount a host path here |
| `EZA_VERSION` | `v0.23.4` | Pinned eza release; bump deliberately |
| `EZA_SHA256_AMD64` | _(pinned)_ | sha256 of the amd64 eza tarball; regenerate on bump |
| `EZA_SHA256_ARM64` | _(pinned)_ | sha256 of the arm64 eza tarball; regenerate on bump |
| `BASHIFY_REF` | _(pinned commit)_ | Commit of bashify's `install.sh`; bump to update |

> **Reproducibility:** `eza` and `bashify` are pinned (version + per-arch
> checksum for eza, commit ref for bashify) rather than tracking `latest`/`HEAD`,
> so rebuilds are deterministic and cannot be silently altered upstream. To
> upgrade either, bump its arg and — for eza — regenerate the checksums:
>
> ```bash
> curl -fsSL https://github.com/eza-community/eza/releases/download/<ver>/eza_x86_64-unknown-linux-musl.tar.gz | sha256sum
> ```

## Custom Shell Features

### Bashify Prompt

A lightweight, modular prompt system from [beratiyilik/bashify](https://github.com/beratiyilik/bashify), fetched at build time and installed at `/usr/local/lib/bashify/bashify.bash`, then sourced automatically via `.bashrc`. A starter config is seeded to `~/.config/bashify/bashifyrc` on first container start (never overwriting an existing one).

**Left side segments** (always shown):

| Segment | Description |
| ------- | ----------- |
| `dir` | Current directory with compact path formatting |
| `git` | Branch name, staged/unstaged/untracked counts, stash, ahead/behind, conflicts |
| `prompt_char` | `❱` — green on success, red on failure |
| `status` | Exit code shown when non-zero |

**Right side segments** (disabled automatically inside Docker and dumb terminals):

| Segment | Description |
| ------- | ----------- |
| `jobs` | Background job count (blinks when active) |
| `node` | Node.js version when in a project with `package.json` |
| `bashver` | Current Bash version |
| `time` | Current time |

**Path display styles** (set via `BASHIFY_DIR_STYLE`):

| Style | Description |
| ----- | ----------- |
| `full` | Full path with anchor-colored final component |
| `shortened` | Truncates middle components with `...` when path exceeds max length |
| `compact` | First letter of each parent directory |
| `compactalt` | Variable-length prefix per depth level (default) |
| `name` | Current directory name only |

To override defaults, edit `~/.config/bashify/bashifyrc` (seeded on first start), set
`BASHIFY_USER_CONFIG` to point elsewhere, or use the legacy `~/.bashifyrc`:

```bash
BASHIFY_RIGHT_PROMPT_ENABLED=false   # disable right prompt
BASHIFY_DIR_STYLE=full               # use full path
BASHIFY_GIT_SHOW_AHEAD_BEHIND=false  # skip remote tracking
```

### Aliases

#### Listing (`eza` with fallback to `ls`)

| Alias | Command |
| ----- | ------- |
| `ls` | Icons, directories first |
| `ll` | Long format, hidden files, git status |
| `la` | Long format with hidden files |
| `l` | One item per line |
| `lt` | Long tree view with hidden files |
| `lta` | Long tree view (all files) |
| `tree` | Tree view, ignores `.git`, `node_modules`, `*.log` |

#### Navigation & General

| Alias | Description |
| ----- | ----------- |
| `..` | Go up one directory |
| `~` | Go to home directory |
| `ws` | Jump to the workspace/output dir (`$WORKDIR_PATH`, default `/workspace`) |
| `c` | Clear terminal |
| `cl` | Clear and list directory |
| `cls` | Clear and list directory (short) |
| `d` | Show directory stack (`dirs -v`) |
| `h` | Show command history |
| `reload` | Reload `.bashrc` |
| `path` | Print `$PATH` entries one per line |

#### Safety (interactive confirmation)

| Alias | Description |
| ----- | ----------- |
| `cp` | Copy with confirmation and verbose output |
| `mv` | Move with confirmation and verbose output |
| `rm` | Remove with confirmation and verbose output |
| `mkdir` | Create directories recursively with verbose output |
| `rmrf` | Force-remove recursively (no confirmation) |

#### Docker

| Alias | Description |
| ----- | ----------- |
| `dps` | List containers with name, status, ports |
| `drm` | Force-remove a container |
| `dl` | Follow container logs |
| `dex` | Exec into a container interactively |
| `di` | List images |
| `db` | Build an image |
| `dri` | Force-remove an image |
| `dpurge` | Prune all containers, images, networks, and volumes |
| `dc` | `docker compose` shorthand |
| `dcu` | `docker compose up -d` |
| `dcs` | `docker compose stop` |
| `dcd` | `docker compose down` |
| `dcd2` | `docker compose down` with orphan/volume/image cleanup |
| `dcr` | `docker compose restart` |

### History Management

- **In-memory**: 10,000 commands (`HISTSIZE`)
- **On-disk**: 100,000 commands (`HISTFILESIZE`)
- **Filtering**: Ignores common low-value commands (`ls`, `cd`, `exit`, `clear`, `docker ps`, etc.)
- **Deduplication**: Consecutive duplicates and commands preceded by a space are ignored

## Security

### What this image gives you

- **Non-root execution**: Default user is `devuser` (UID 1001), not root
- **Reproducible, pinned dependencies**: `eza` (version + checksum) and
  `bashify` (commit) cannot be silently swapped upstream
- **Shared permissions**: Group-based file access via the `shared` group (GID 2001)
- **Signal handling**: Graceful shutdown on `SIGTERM`/`SIGINT`/`SIGHUP`, plus a
  real init (`--init`) that reaps zombie processes in long-lived containers

### What it does NOT give you (read this)

**`/workspace` is an organizational convention, not a sandbox.** Putting work
there does not isolate or quarantine anything.

- A program run in the container — including a malicious download or binary —
  executes with `devuser`'s rights **inside** the container and can read/write
  everything the container can, including any mounted volume.
- **A bind mount is a two-way door.** If `./workspace` on the host is mounted to
  `/workspace`, code in the container can write to (and delete from) the host's
  `./workspace`. "Host-accessible output" and "place malware can reach the host"
  are the same path.
- **Network egress is open by default.** The container can download and exfiltrate
  freely; the working directory does nothing to stop that.
- **A container is not a strong trust boundary.** Kernel exploits, `--privileged`,
  or mounting the Docker socket can lead to host compromise. This image mounts no
  Docker socket — do not add one for untrusted workloads.

### If you need to run untrusted code

The convention won't protect you; explicit run-time controls will. Consider:

- `--security-opt no-new-privileges` and `--cap-drop ALL` to shrink privilege
- `--read-only` root filesystem + `--tmpfs` for writable paths
- `--network none` to cut egress entirely
- `--memory` / `--cpus` resource limits
- A dedicated, disposable host directory for the bind mount — never your home or
  source tree
- Stronger isolation (VM, gVisor, rootless Docker) for genuinely hostile inputs

## Health Monitoring

The container health check verifies that entrypoint initialization completed successfully:

- **Check**: `test -f /tmp/.container_ready` — flag written by `entrypoint.sh` after setup
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Start period**: 10 seconds
- **Retries**: 3

## Environment Variables

| Variable | Description |
| -------- | ----------- |
| `DEBIAN_FRONTEND` | Set to `noninteractive` to prevent interactive prompts during build |
| `LANG`, `LANGUAGE`, `LC_ALL` | UTF-8 locale configuration |
| `TZ` | Timezone set to `UTC` |
| `CONTAINER_USER` | The configured username, injected at build time |

## Entrypoint Behavior

`entrypoint.sh` runs before any `CMD` and is responsible for:

1. **Logging startup context**: user, UID/GID, hostname, kernel, and working directory
2. **Installing `.bashrc`**: backs up any existing `.bashrc` to `/tmp`, then copies the custom one from `/var/tmp/container_resources/`
3. **Enabling Bashify**: idempotently appends a `source` line for `/usr/local/lib/bashify/bashify.bash` to `.bashrc`, and seeds the starter config to `~/.config/bashify/bashifyrc` if absent
4. **Signal handling**: catches `SIGTERM`, `SIGINT`, and `SIGHUP` for clean container shutdown
5. **Health flag**: writes `/tmp/.container_ready` on successful initialization
6. **CMD passthrough**: hands off to `exec "$@"`, falling back to `/bin/bash` if no arguments are given

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.
