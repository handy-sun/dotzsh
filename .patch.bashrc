#!/bin/bash

dus(){
    du $1 -alh -d1 | sort -rh | head -n 11
}

rlip4(){
    ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1
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

alias hds='rm -f /tmp/tdh_hds.db && /root/sunq/TdhHdsMain'
alias qwe='rz -bye'
alias ltr='ll /opt/tftpboot/ramdisk'
alias ltk='ll /opt/tftpboot/ramdisk | grep tk'
alias tkbo='cd /opt/lxrd/lxroot/`readlink -n /opt/tftpboot/ramdisk/tk_bono`'

_get_short_pwd(){
    split=4
    W=$(pwd | sed -e "s!$HOME!~!")
    # W=${PWD/#"$HOME"/~}
    total_cnt=$(echo $W | grep -o '/' | wc -l)
    last_cnt=$(($total_cnt-1))
    if [ $total_cnt -gt $split ]; then
        echo $W | cut -d/ -f1-2 | xargs -I{} echo {}"/…/$(echo $W | cut -d/ -f${last_cnt}-)"
    else
        echo $W
    fi
}

_prompt_cmd(){
    [[ $? -eq 0 ]] && local ps1ArrowFgColor="92" || local ps1ArrowFgColor="91"
    local usper=`df | grep -E '/$' | awk '{print$(NF-1);}' | tr -d '%'`
    PS1="\[\e[0m\]\[\033[0;32m\]\A \[\033[0;31m\]${usper}\[\e[0m\] \[\e[0;36m\]\w \[\e[0;${ps1ArrowFgColor}m\]\\$\[\e[0m\] "
}

if [[ -n "$BASH_VERSION" ]]; then
    PROMPT_COMMAND=_prompt_cmd
    HISTCONTROL=ignoredups:erasedups:ignorespace # no duplicate entries
    shopt -s histappend
fi

export HISTTIMEFORMAT='%F %T '
export TERM=xterm-256color

## change /etc/profile TMOUT
# 3 days
export TMOUT=259200

