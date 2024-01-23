#!/bin/bash

dus(){
    du $1 -alh -d1 | sort -rh | head -n 11
}

ctner_ip4(){
    ip -o -4 addr list | grep -Ev '\s(lo)' | awk '{print $4}' | cut -d/ -f1
}

[ -z "$LS_OPTIONS" ] && export LS_OPTIONS="--color=auto"
alias ls="ls $LS_OPTIONS"
alias ll='ls -AlF'

alias rm='rm -f'
alias cp='cp -f'
alias gdb='gdb -q'

alias tarx="tar --no-same-owner -xf"
alias tarz="tar zcf"
alias grep >/dev/null 2>&1 || alias grep="grep --color=auto"

_prompt_cmd(){
    [[ $? -eq 0 ]] && local ps1ArrowFgColor="92" || local ps1ArrowFgColor="91"
    local ip=`ctner_ip4`
    PS1="\[\e[0m\]\[\033[0;32m\]\A \[\033[0;31m\]${ip}\[\e[0m\] \[\e[0;36m\]\w \[\e[0;${ps1ArrowFgColor}m\]\\$\[\e[0m\] "
}

if [[ -n "$BASH_VERSION" ]]; then
    PROMPT_COMMAND=_prompt_cmd
    HISTCONTROL=ignoredups:erasedups:ignorespace # no duplicate entries
    shopt -s histappend
fi

export HISTTIMEFORMAT='%F %T '
export TERM=xterm-256color
