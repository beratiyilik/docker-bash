FROM ubuntu:26.04

# build arguments for customization
ARG VERSION=1.0.0
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
# ARG USERNAME=root  # avoid running as root; use a named non-root user
# ARG UID=0
# ARG GID=0
ARG USERNAME=devuser
ARG UID=1001
ARG GID=1001
ARG SHARE_GID=2001

# canonical, host-mountable working/output directory (single source of truth).
# this is an organizational convention, NOT a security boundary — see README.
ARG WORKDIR_PATH=/workspace

# pinned third-party versions for reproducible builds. bump deliberately.
# eza checksums are per-arch; regenerate when bumping EZA_VERSION:
#   curl -fsSL <tarball-url> | sha256sum
ARG EZA_VERSION=v0.23.4
ARG EZA_SHA256_AMD64=d231bb3ee33b08c76279b5888845dceb7034d055c42bb9be46dbe0dae39394df
ARG EZA_SHA256_ARM64=366e8430225f9955c3dc659b452150c169894833ccfef455e01765e265a3edda
# bashify install source pinned to a commit so upstream changes cannot
# silently alter the image. bump deliberately to adopt upstream updates.
ARG BASHIFY_REF=efa123b25a8e129d9d911ef0bd942051c5077328

# metadata and labels
LABEL maintainer="Berat Iyilik <info@domain.com>"
LABEL version="${VERSION}"
LABEL description="Development container based on Ubuntu 26.04 with essential networking and utility tools"
LABEL org.opencontainers.image.authors="Berat Iyilik"
LABEL org.opencontainers.image.title="husk"
LABEL org.opencontainers.image.source="https://github.com/beratiyilik/husk"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# use bash with pipefail for better error handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# prevent interactive prompts and set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    CONTAINER_USER=${USERNAME} \
    WORKDIR_PATH=${WORKDIR_PATH} \
    BASHIFY_DIR=/usr/local/lib/bashify

# install necessary packages and clean up in a single layer
RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        locales \
        tzdata \
        bash \
        bash-completion \
        less \
        nano \
        vim \
        curl \
        wget \
        dnsutils \
        openssh-client \
        coreutils \
        git \
        grep \
        jq \
        make \
        unzip \
        procps \
        python3 \
        python3-pip \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# eza is not in Ubuntu's apt repo; install the prebuilt binary from GitHub.
# Detects architecture at build time to support both amd64 and arm64.
# Version is pinned (EZA_VERSION) and the download is verified against a
# per-arch sha256 so the build is reproducible and cannot be silently swapped.
ARG EZA_VERSION
ARG EZA_SHA256_AMD64
ARG EZA_SHA256_ARM64
RUN set -eux && \
    ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        amd64) EZA_ARCH="x86_64-unknown-linux-musl"; EZA_SHA256="${EZA_SHA256_AMD64}" ;; \
        arm64) EZA_ARCH="aarch64-unknown-linux-gnu"; EZA_SHA256="${EZA_SHA256_ARM64}" ;; \
        *)     echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/eza.tar.gz \
        "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_${EZA_ARCH}.tar.gz" && \
    echo "${EZA_SHA256}  /tmp/eza.tar.gz" | sha256sum -c - && \
    tar -xz -C /tmp -f /tmp/eza.tar.gz && \
    mv /tmp/eza /usr/local/bin/eza && \
    chmod +x /usr/local/bin/eza && \
    rm -f /tmp/eza.tar.gz

# create shared group and directory for shared resources
RUN set -eux \
    && groupadd --gid "${SHARE_GID}" shared || true \
    && usermod -a -G shared root \
    && mkdir -p /var/tmp/container_resources

# create non-root user if USERNAME is not root;
# useradd may fail if UID is already taken (e.g. on rebuilt images) — tolerated via || true;
# usermod only runs if the user was actually created to avoid silent group membership failure
RUN set -eux && \
    if [ "${USERNAME}" != "root" ]; then \
        groupadd --gid "${GID}" "${USERNAME}" || true; \
        useradd --uid "${UID}" --gid "${GID}" -m -s /bin/bash "${USERNAME}" || true; \
        id "${USERNAME}" &>/dev/null && usermod -a -G shared "${USERNAME}"; \
    fi

# copy the entrypoint script and source files
COPY entrypoint.sh /usr/local/bin/
COPY src/ /var/tmp/container_resources/

# install bashify from upstream as a system-wide shell library accessible to all users
# upstream: https://github.com/beratiyilik/bashify
# install.sh is fetched from a pinned ref (BASHIFY_REF) so upstream changes
# cannot silently alter the image; bump BASHIFY_REF deliberately to update.
ARG BASHIFY_REF
RUN set -eux && \
    RC_FILE=/dev/null \
        /bin/bash -c "$(curl -fsSL "https://raw.githubusercontent.com/beratiyilik/bashify/${BASHIFY_REF}/install.sh")" && \
    rm -rf "${BASHIFY_DIR}/.git" && \
    chmod -R a+rX "${BASHIFY_DIR}"

# set permissions for scripts and shared directory
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R root:shared /var/tmp/container_resources && \
    chmod -R 0644 /var/tmp/container_resources && \
    find /var/tmp/container_resources -type d -exec chmod 0755 {} \;

# WORKDIR_PATH is the canonical, host-mountable working/output directory and is
# the single source of truth for "where work lands". Mount a host path or named
# volume here (see docker-compose.yml / Makefile) so outputs survive the
# container and are reachable from the host. Config/dotfiles stay in $HOME.
#
# Owned by the primary user and the shared group, with the setgid bit (2775) so
# files created here inherit the shared group regardless of who writes them.
#
# NOTE: this is an organizational convention, not an isolation boundary. Code
# run in the container can read/write anything mounted here, including the host
# side of a bind mount. See the Security section of the README.
RUN set -eux; \
    install -d -m 2775 "${WORKDIR_PATH}"; \
    if id "${USERNAME}" &>/dev/null; then \
        chown "${USERNAME}:shared" "${WORKDIR_PATH}"; \
    else \
        chown "root:shared" "${WORKDIR_PATH}"; \
    fi

WORKDIR ${WORKDIR_PATH}

# drop privileges to the configured user
USER ${USERNAME}

# health check: passes once entrypoint.sh creates /tmp/.container_ready,
# confirming the initialization sequence completed successfully
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD test -f /tmp/.container_ready || exit 1

# set the entrypoint.sh to the script that prepares the environment
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]

# default command to run when container starts (an interactive bash shell)
CMD ["/bin/bash"]