FROM ubuntu:24.04

# build arguments for customization
ARG VERSION=1.0.0
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
ARG USERNAME=root
ARG UID=0
ARG GID=0
ARG SHARE_GID=2001

# metadata and labels
LABEL maintainer="Berat Iyilik <info@domain.com>"
LABEL version="${VERSION}"
LABEL description="Development container based on Ubuntu 24.04 with essential networking and utility tools"
LABEL org.opencontainers.image.authors="Berat Iyilik"
LABEL org.opencontainers.image.source="https://github.com/beratiyilik/docker-bash"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.licenses="MIT"

# use bash with pipefail for better error handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# prevent interactive prompts and set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    CONTAINER_USER=${USERNAME}

# install necessary packages and clean up in a single layer
RUN set -eux && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # core system, locales, time
        ca-certificates \
        locales \
        tzdata \
        # shell and editors
        bash \
        bash-completion \
        less \
        nano \
        vim \
        # networking and transfer
        curl \
        wget \
        dnsutils \
        openssh-client \
        # development and utilities
        coreutils \
        git \
        grep \
        jq \
        make \
        unzip \
        eza \
        procps \
        # runtimes
        python3 \
        python3-pip \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# create shared group and directory for shared resources
RUN set -eux \
    && groupadd --gid "${SHARE_GID}" shared || true \
    && usermod -a -G shared root \
    && mkdir -p /var/tmp/container_resources

# handle user creation based on USERNAME
RUN set -eux && \
    if [ "${USERNAME}" != "root" ]; then \
        groupadd --gid "${GID}" "${USERNAME}" || true; \
        useradd --uid "${UID}" --gid "${GID}" -m -s /bin/bash "${USERNAME}" || true; \
        usermod -a -G shared "${USERNAME}"; \
    fi

# copy the entrypoint script and source files
COPY entrypoint.sh /usr/local/bin/
COPY src/ /var/tmp/container_resources/

# set permissions for scripts and shared directory
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R root:shared /var/tmp/container_resources && \
    chmod -R 0644 /var/tmp/container_resources && \
    find /var/tmp/container_resources -type d -exec chmod 0755 {} \;

# set the working directory to the user's home directory or /wd
RUN set -eux; \
    HOME_DIR="$(getent passwd "${USERNAME}" | cut -d: -f6)"; \
    ln -snf "${HOME_DIR}" /wd
WORKDIR /wd

# drop privileges
USER ${USERNAME}

# simple health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -fx "bash" >/dev/null || exit 1

# set the entrypoint.sh to the script that prepares the environment
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]

# default command to run when container starts (an interactive bash shell)
CMD ["/bin/bash"]
