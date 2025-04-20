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

# ansi color & effect constants (safe ps1 use)
RESET="\[\033[0m\]"
BOLD="\[\033[1m\]"
BLINK_ON="\[\033[5m\]"
BLINK_OFF="\[\033[25m\]"
RED="\[\033[38;5;196m\]"
GREEN="\[\033[38;5;76m\]"
YELLOW="\[\033[38;5;220m\]"
BLUE="\[\033[38;5;31m\]"
MAGENTA="\[\033[0;35m\]"
CYAN="\[\033[38;5;66m\]"
WHITE="\[\033[0;37m\]"

# detect chroot (debian-based), skip if in docker
if [[ -z "$debian_chroot" ]] && [[ -r /etc/debian_chroot ]] && ! grep -qE '(docker|lxc|container)' /proc/1/cgroup 2>/dev/null; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# red color for root user in prompt
_get_user() {
    if [ "$(whoami)" = "root" ]; then
        echo "$RED\u$RESET"
    else
        echo "$GREEN\u$RESET"
    fi
}

# external (vps) or internal (docker) ip
_get_ip_identity() {
    local ip=""

    if [ -f /.dockerenv ] || grep -qE '(docker|lxc|container)' /proc/1/cgroup 2>/dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    else
        ip=$(curl -s --max-time 1 ifconfig.me 2>/dev/null)
    fi

    # fallback: hostname
    if [[ -z "$ip" ]]; then
        ip=$(hostname)
    fi

    if [[ -n "$ip" ]]; then
        echo -e "${MAGENTA}@${ip}${RESET}"
    else
        echo ""
    fi
}

# container or host id detection
_get_container_id() {
    if [ -f /.dockerenv ]; then
        cid=$(cat /etc/hostname | cut -c1-12)
        echo -e " ${CYAN}[#${cid}]${RESET}"
    elif grep -qE '(docker|lxc|container)' /proc/1/cgroup 2>/dev/null; then
        echo -e " ${CYAN}[@container]${RESET}"
    else
        echo ""
    fi
}

# background jobs indicator
_get_jobs_indicator() {
    local job_count=$(jobs -p | wc -l)

    if [ "$job_count" -eq 1 ]; then
        echo "${YELLOW}${BLINK_ON}[⚙]${BLINK_OFF}${RESET}"
    elif [ "$job_count" -gt 1 ]; then
        echo "${YELLOW}${BLINK_ON}[⚙ ${job_count}]${BLINK_OFF}${RESET}"
    else
        echo ""
    fi
}

# git branch and working status
_parse_git_branch() {
    command -v git >/dev/null 2>&1 || return
    git rev-parse --git-dir &>/dev/null || return

    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local status=""

    [[ -n $(git status --porcelain 2>/dev/null | grep '^\s*M') ]] && status+="*"
    [[ -n $(git status --porcelain 2>/dev/null | grep '^ M') ]] && status+="+"
    [[ -n $(git status --porcelain 2>/dev/null | grep '^??') ]] && status+="!"
    [[ -z "$status" ]] && status="✔"

    echo -e " ${YELLOW}[${branch}${status}]${RESET}"
}

# set dynamic prompt
set_prompt() {
    local exit_status=$?
    local debian_prefix="${debian_chroot:+($debian_chroot)}"
    local user="$(_get_user)"
    local ip="$(_get_ip_identity)"
    local container_id="$(_get_container_id)"
    local jobs_indicator="$(_get_jobs_indicator)"
    local cwd="${BOLD}${BLUE}\w${RESET}"
    local git_branch="$(_parse_git_branch)"

    # last command exit status display
    local status_text=""
    if [ $exit_status -ne 0 ]; then
        status_text="${RED}[✖ $exit_status]${RESET}"
    fi

    local prompt="${debian_prefix}${user}${ip}${container_id}${jobs_indicator}${status_text}\n${cwd} ${git_branch}\$ "
    export PS1="${prompt}"
}

# hook prompt update
PROMPT_COMMAND=set_prompt

#############################################################################
# FUNCTIONS
#############################################################################

#############################################################################
# ALIASES
#############################################################################

# initialize dircolors if available
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b)"
fi

# useful aliases and colored output
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

# aliases
alias c='clear'
alias cl='clear; la'
alias cls='clear; ls'
alias d='dirs -v'
alias h='history'
alias ..='cd ..'
alias ~='cd ~'
alias reload='source ~/.bashrc'
alias path='echo "$PATH" | tr ":" "\n"'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'
alias mkdir='mkdir -pv'
alias rmrf='rm -rf'

# docker aliases
if command -v docker >/dev/null 2>&1; then
    alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias dimg='docker images'
    alias dlog='docker logs -f'
    alias dexec='docker exec -it'
fi

#############################################################################
# EXTERNAL TOOL INTEGRATIONS
#############################################################################

# lesspipe support for smart paging
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# enable bash completion if exists
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

## eof
