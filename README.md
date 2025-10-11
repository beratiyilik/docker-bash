# Ubuntu Development Container

A comprehensive, production-ready Docker development environment based on Ubuntu 24.04 with essential networking, development tools, and a feature-rich custom `.bashrc` configuration.

## 🔧 Features

### Core System

- **Base**: Ubuntu 24.04 LTS for stability and compatibility
- **Locales**: Full UTF-8 support (en_US.UTF-8)
- **User Management**: Configurable non-root user with proper permissions
- **Security**: Non-root execution by default with shared group access

### Pre-installed Tools

- **System & Core**: `ca-certificates`, `locales`, `tzdata`, `coreutils`, `procps`
- **Shell & Editors**: `bash`, `bash-completion`, `nano`, `vim`, `less`
- **Networking**: `curl`, `wget`, `dnsutils`, `openssh-client`
- **Development**: `git`, `make`, `python3`, `python3-pip`
- **Utilities**: `grep`, `jq`, `unzip`, `eza` (modern ls replacement)

### Custom Shell Environment

- **Dynamic Prompt**: Shows user, IP/hostname, container ID, git status, background jobs
- **Smart Aliases**: Enhanced `ls` commands with `eza`, Docker shortcuts, safety aliases
- **Git Integration**: Branch and status indicators in prompt
- **History Management**: Large history with intelligent filtering
- **Container Detection**: Automatic detection of Docker/container environments

## 📁 Project Structure

```text
.
├── Dockerfile            # Multi-stage Ubuntu 24.04 container definition
├── entrypoint.sh         # Environment setup and initialization script
├── LICENSE               # GPL v3 license
├── README.md             # This documentation
└── src/
    └── .bashrc           # Custom Bash configuration with prompt and aliases
```

## 🚀 Usage

### Quick Start

#### 1. Basic Build

```bash
docker build -t ubuntu-dev:24.04 .
```

#### 2. Advanced Build with Custom Arguments

```bash
docker build -t ubuntu-dev:24.04 \
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
docker run -it --hostname devbox --name devbox ubuntu-dev:24.04
```

#### 2. Development Container with Volume Mount

```bash
docker run -it \
  --hostname $(hostname) \
  --name dev \
  -v "$(pwd):/workspace" \
  ubuntu-dev:24.04
```

#### 3. Background Development Server

```bash
docker run -d \
  --name dev-server \
  --hostname dev-server \
  -v "$(pwd):/workspace" \
  -p 8080:8080 \
  ubuntu-dev:24.04 \
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

## ⚙️ Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `1.0.0` | Image version for metadata |
| `VCS_REF` | `unknown` | Git commit hash for traceability |
| `BUILD_DATE` | `unknown` | Build timestamp (ISO 8601) |
| `USERNAME` | `root` | Primary user (creates non-root if not 'root') |
| `UID` | `0` | User ID for the primary user |
| `GID` | `0` | Group ID for the primary user |
| `SHARE_GID` | `2001` | Shared group ID for resource access |

## 🎨 Custom Shell Features

### Dynamic Prompt Components

- **User indicator**: Green for normal users, red for root
- **Network identity**: External IP for hosts, internal IP for containers
- **Container ID**: Displays container hostname or ID when in container
- **Background jobs**: Visual indicator with job count
- **Git status**: Branch name with working directory status symbols
- **Exit status**: Shows last command exit code if non-zero

### Smart Aliases

- **Enhanced listing**: `ll`, `la`, `l`, `lt` with `eza` or fallback to `ls`
- **Docker shortcuts**: `dps`, `dl`, `dex`, `dcu`, `dcd` for common operations
- **Safety aliases**: Interactive `cp`, `mv`, `rm` commands
- **Navigation**: Quick `..`, `~`, `c` (clear), `reload` commands

### History Management

- **Large history**: 10,000 commands in memory, 100,000 in file
- **Smart filtering**: Ignores common commands to reduce noise
- **Duplicate handling**: Removes consecutive duplicates

## 🔒 Security Features

- **Non-root execution**: Drops privileges after setup
- **Shared permissions**: Proper group-based file access
- **Signal handling**: Graceful shutdown on SIGTERM/SIGINT
- **Resource isolation**: Dedicated shared directory with proper permissions

## 🏥 Health Monitoring

The container includes a health check that monitors the bash process:

- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start period**: 5 seconds
- **Retries**: 3

## 📋 Environment Variables

| Variable | Description |
|----------|-------------|
| `DEBIAN_FRONTEND` | Set to `noninteractive` to prevent prompts |
| `LANG`, `LC_ALL` | UTF-8 locale configuration |
| `TZ` | Timezone set to UTC |
| `CONTAINER_USER` | References the configured username |

## 🔄 Entrypoint Features

The `entrypoint.sh` script provides:

- **Environment logging**: User, host, and system information
- **Bashrc management**: Automatic backup and installation of custom config
- **Signal handling**: Graceful cleanup on container stop
- **Error handling**: Comprehensive error reporting and exit codes

## 📝 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
