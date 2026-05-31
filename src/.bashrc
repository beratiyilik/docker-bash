## ~/.bashrc

# skip non-interactive shells
[[ -z "$PS1" ]] && return

#############################################################################
# SHELL CONFIGURATION
#############################################################################

# locale, history and safety options
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
set -o noclobber

HISTCONTROL=ignoredups:ignorespace
HISTSIZE=10000
HISTFILESIZE=100000
HISTIGNORE="ls:ll:cd:pwd:exit:clear:history:c:whoami:hostname:ip:~:nano:cat:ls -a:ls -la:ls -l:mkdir:curl -I *:docker ps*:docker logs*:docker-compose down*:docker-compose up*"

shopt -s histappend
shopt -s checkwinsize

#############################################################################
# PROMPT CONFIGURATION
#############################################################################

# load bashify — standalone prompt library (github.com/beratiyilik/bashify),
# installed system-wide at build time. BASHIFY_DIR is exported via ENV in the
# Dockerfile (single source of truth); fall back to the default if it is unset.
# shellcheck source=/dev/null
[[ -f "${BASHIFY_DIR:-/usr/local/lib/bashify}/bashify.bash" ]] \
    && source "${BASHIFY_DIR:-/usr/local/lib/bashify}/bashify.bash"

#############################################################################
# ALIASES
#############################################################################

# initialize dircolors if available
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"
fi

# listing aliases — prefer eza if available, fall back to ls
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -lha --icons --group-directories-first --git"
    alias la="eza -la --icons --group-directories-first"
    alias l="eza --icons --group-directories-first --oneline"
    alias lt="eza -lhaT --icons --group-directories-first --git"
    alias lta="eza -lhaT --icons --group-directories-first"
    alias tree="eza --tree --icons --all --ignore-glob='.git,node_modules,*.log'"
else
    _ls_group=""
    ls --group-directories-first / >/dev/null 2>&1 && _ls_group="--group-directories-first"
    alias ls="ls --color=auto -F $_ls_group"
    alias ll="ls -lha --color=auto -F $_ls_group"
    alias la="ls -A --color=auto -F $_ls_group"
    alias l="ls -CF --color=auto -F $_ls_group"
    alias lt="ls -lhaR --color=auto -F $_ls_group"
    alias lta="ls -lhaR --color=auto -F $_ls_group"
    alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
fi

if command -v grep >/dev/null 2>&1; then
    alias grep='grep --color=auto'
fi

if command -v less >/dev/null 2>&1; then
    alias less='less -R'
fi

# general aliases
alias c='clear'
alias cl='clear; la'
alias cls='clear; ls'
alias d='dirs -v'
alias h='history'
alias ..='cd ..'
alias ~='cd ~'
alias ws='cd "${WORKDIR_PATH:-/workspace}"'   # jump straight to the workspace/output dir
alias reload='source ~/.bashrc'
alias path='echo "$PATH" | tr ":" "\n"'

# safety aliases — interactive mode prevents accidental overwrites/deletions
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'
alias mkdir='mkdir -pv'
alias rmrf='rm -rf'

# docker aliases
if command -v docker >/dev/null 2>&1; then
    alias dokcer="docker"   # intentional typo-guard: common misspelling of `docker`
    alias dps='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias drm="docker rm -f"
    alias dl="docker logs -f"
    alias dex="docker exec -it"
    alias di="docker images"
    alias db="docker build"
    alias dri="docker rmi -f"
    alias dpurge="docker system prune -a --volumes"
    alias dc="docker compose"
    alias dcu="docker compose up -d"
    alias dcs="docker compose stop"
    alias dcd="docker compose down"
    alias dcd2="docker compose down --remove-orphans --volumes --rmi all"
    alias dcr="docker compose restart"
fi

#############################################################################
# EXTERNAL TOOL INTEGRATIONS
#############################################################################

# lesspipe support for smart paging
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# enable bash completion if available
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

## eof
