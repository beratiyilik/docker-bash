# use the official Alpine-based Bash image (lightweight, fast)
FROM bash:devel-alpine3.21

# metadata for clarity
LABEL maintainer="your.name@example.com" \
      version="1.0" \
      description="Alpine-based Bash container with enhanced environment"

# install essential tools:
# - curl: for HTTP requests
# - git: for version control
# - grep: for text searching
# - coreutils: for common UNIX commands (e.g., cp, mv, ls, etc.)
# - bash-completion: for command autocompletion in Bash
# - nano: a simple text editor
# - less: for viewing files
# - jq: for processing JSON data
# - eza: a modern replacement for ls with additional features
# - unzip: for extracting zip files
# - openssh: for secure shell access
RUN apk upgrade --no-cache \
    && apk add --no-cache curl git grep coreutils bash-completion \
    nano less jq eza unzip openssh

# switch to bash as the default shell (consistency)
SHELL ["/bin/bash", "-c"]

# copy your custom .bashrc into a temporary location inside the container
COPY .bashrc /tmp/.bashrc_custom

# copy the entrypoint script that will back up and install the custom .bashrc
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# make the entrypoint script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# set the entrypoint to the script that prepares the environment
ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]

# default command to run when container starts (an interactive Bash shell)
CMD ["bash"]
