# Custom Bash Environment (Alpine-based)

A lightweight, fast Dockerized Bash shell with essential tools and a custom `.bashrc` configuration — built on the official `bash:devel-alpine3.21` image.

## 🔧 Features

- Based on **Alpine Linux** for minimal footprint.
- Pre-installed essentials:
  - `curl` – HTTP requests
  - `git` – version control
  - `grep` – text searching
  - `coreutils` – UNIX utilities
  - `bash-completion` – shell autocompletion
  - `nano` – text editor
  - `less` – file pager
  - `jq` – JSON processor
  - `eza` – modern `ls` replacement
  - `unzip` – archive extraction
  - `openssh` – secure shell
- Automatically backs up the default `.bashrc` and installs your custom one.

## 📁 Project Structure

```
.
├── Dockerfile
├── .bashrc               # Your custom Bash configuration
├── entrypoint.sh         # Startup script for setup
```

## 🚀 Usage

### 1. Build the image
```bash
docker build -t custom-bash-env .
```

### 2. Run the container
```bash
docker run -it --name mybash custom-bash-env
```

### 3. Restart the shell
```bash
docker start -ai mybash
```

### 4. Stop the container
```bash
docker stop mybash
```

### 5. Remove the container
```bash
docker rm mybash
```

## ✅ Notes

- Custom `.bashrc` is installed on first run.
- The original `.bashrc` (if any) is backed up as `.bashrc.bak`.
