## define some func,alias,variable in zsh/bash shell script
# ----------------------- shell function ----------------------
# about git stash
shpo(){
    git stash pop stash@{${1}};
}
shap(){
    git stash apply stash@{${1}};
}
shsw(){
    git stash show -p stash@{${1}};
}
shdr(){
    git stash drop stash@{${1}};
}
# get pid of a process, avoid some Linux system cannot use 'pgrep' command
pgre(){
    ps -ef | grep "${1}" | grep -v grep | awk '{print$2;}'
}
# print all info
ppre(){
    ps -ef | grep "${1}" | grep -v grep
}
# final location of which command
fwhich(){
    local whi=`which ${1} 2>/dev/null`
    [ $? -eq 0 -a -x ${whi} 2>/dev/null ] && readlink -f ${whi} || echo "Error:${whi}"
}
# tar compress/uncompress gzip with pigz
tcpzf(){
    type pigz >/dev/null 2>&1 || { echo "Not install pigz !"; return 1; }
    tar cf - ${2} | pigz --fast > ${1}
}
txpz(){
    type pigz >/dev/null 2>&1 || { echo "Not install pigz !"; return 1; }
    tar --no-same-owner -xf ${1} -I pigz
}
dus(){
    du $1 -alh -d1 | sort -rh | head -n 11
}
# get real network device local ipv4 address
rlip4(){
    ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1
}
# quickly update git repo between remote and local
gitur(){
    set -x
    git add `git status -s | grep -vE '^\?\?|  ' | awk '{print$2;}'`
    [ $? -eq 0 ] || return 1

    git commit
    git pull --rebase && git push || echo 'handle conflicts first!'
}
jnl(){
    journalctl -eu $1 | less +G
}
jfxe(){
    journalctl -n 100 -fxeu $1
}
dkcid(){
    docker ps -qf "name= $1\$"
}
dktty(){
    local ctn_id=`dkcid $1`
    [[ -z "$ctn_id" ]] && { echo "ERROR:no such container: $1!"; return 1; }

    local ctn_count=`echo $ctn_id | wc -l`
    [ $ctn_count -gt 1 ] && { echo "ERROR: $ctn_count containers found, cannot exec shell!"; return 1; }

    docker exec -ti $ctn_id /bin/bash 2>/dev/null || docker exec -ti $ctn_id /bin/sh
}
# ----------------------- alias ----------------------
# git
alias gta="git status"
alias gts="git status -s"
alias gtun="git status uno"

alias gcm="git commit"
alias gcmm="git commit -m"
alias gcma="git commit -a"
alias gcmn="git commit --amend"
alias gcman="git commit -a --amend"

alias gpl="git pull"
alias gplrb="git pull --rebase"

alias gsh="git stash"
alias gshl="git stash list"

alias grs="git reset"
alias grsh="git reset --hard"
alias grss="git reset --soft"
alias gstag="git restore --staged"

alias glg="git log --pretty=format:'%Cred%h%Creset -%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset %C(yellow)%d' --abbrev-commit --color"
alias glp="git log --pretty=format:'%Cred%h%Creset -%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset %C(yellow)%d' --abbrev-commit --color --graph"
alias glh="git log --pretty=format:'%Cred%h%Creset -%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset %C(yellow)%d' --abbrev-commit --color --graph | head -30"

alias gdf="git diff"
alias gdfh="git diff HEAD"
alias gdfc="git diff --cached"
alias gbr="git branch"
alias gba="git branch -a"
alias gtl="git tag --list"
alias gck="git checkout"
alias grt="git remote -v"
alias gblm="git blame -L"
alias gaprj="git apply --reject"
# tar
alias tarx="tar --no-same-owner -xf"
alias tarz="tar zcf"

# systemctl
alias syta="systemctl status"
alias syst="sudo systemctl start"
alias syrs="sudo systemctl restart"
alias syte="sudo systemctl stop"
alias syrld="sudo systemctl reload"
alias syen="sudo systemctl enable"
alias syenw="sudo systemctl enable --now"
alias sydis="sudo systemctl disable"
alias sydisw="sudo systemctl disable --now"
alias sydmrld="sudo systemctl daemon-reload"

# cmake
export BUILD_DIR="./build"
alias cmkln="rm -rf ${BUILD_DIR}/CMakeCache.txt ${BUILD_DIR}/CMakeFiles/"
alias cmkr="cmake -B${BUILD_DIR} -G 'Ninja' -DCMAKE_BUILD_TYPE=Release"
alias cmkd="cmake -B${BUILD_DIR} -G 'Ninja' -DCMAKE_BUILD_TYPE=Debug"
alias cmba="cmake --build ${BUILD_DIR}"
alias cmb="cmake --build ${BUILD_DIR} -t"

# docker
alias dps="docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
alias dpz="docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}'"
# docker-compose
if type docker-compose >/dev/null 2>&1; then
    export CPO_YML="/var/dkcmpo/docker-compose.yml"
    alias dkcpo="docker-compose -f $CPO_YML"
    alias dkcps="docker-compose -f $CPO_YML ps"
fi

# pacman (archlinux/manjaro)
if type pacman >/dev/null 2>&1; then
    alias pkgins="sudo pacman -Sy"
    alias pkguni="sudo pacman -R"
    alias pkgss="pacman -Ss"
    alias pkgsi="pacman -Si"
    alias pkgssq="pacman -Ssq"
    alias pkgqs="pacman -Qs"
    alias pkgqi="pacman -Qi"
    alias pkgql="pacman -Ql"
    alias pkgqo="pacman -Qo"
fi

[[ -z "$LS_OPTIONS" ]] && export LS_OPTIONS="--color=auto"
alias ls="ls -A $LS_OPTIONS"
alias ll="ls -AlFh"
alias l="ls -AlF"
alias la="ls -alF"

# other shell
alias pingk="ping -c 4"
alias gdb="gdb -q"
alias cp="cp -arvf"
alias less="less -R"
alias df="df -Th"

type trash >/dev/null 2>&1 && alias rm="trash" && alias rrm="/bin/rm -rf"
type xclip >/dev/null 2>&1 && alias pbcopy="xclip -selection clipboard" && alias pbpaste="xclip -selection clipboard -o"
type fd >/dev/null 2>&1 && alias fd="fd -H"

alias grep >/dev/null 2>&1 || alias grep="grep --color=auto"

_get_short_pwd(){
    # echo -n `pwd | sed -e "s!$HOME!~!" | sed "s:\([^/]\)[^/]*/:\1/:g"`
    split=5
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

_ssh_addr(){
    echo $SSH_CLIENT | awk '{print$1}'
}

_prompt_cmd(){
    [[ $? -eq 0 ]] && local ps1ArrowFgColor="92" || local ps1ArrowFgColor="91"
    local shortPwd=`_get_short_pwd`
    # local shortPwd=`p=${PWD/#\"$HOME\"/~};((${#p}>30)) && echo \"${p::10}…${p:(-19)}\" || echo \"\w\"`
    PS1="\[\e[0m\]\[\033[0;32m\]\A \[\e[0;36m\]${shortPwd} \[\e[0;${ps1ArrowFgColor}m\]\\$\[\e[0m\] "
    # PS1='\[\e[0m\]\[\033[0;32m\]\A \[\e[0;36m\]w \[\e[0;${ps1ArrowFgColor}m\]\$\[\e[0m\] '
}

if [[ -n "$BASH_VERSION" ]]; then
    # PROMPT_DIRTRIM=2
    PROMPT_COMMAND=_prompt_cmd
    HISTCONTROL=ignoredups:erasedups:ignorespace # no duplicate entries
    shopt -s histappend
    # history format only worked for bash; zsh can use 'history -i', see 'man zshoptions'
    export HISTTIMEFORMAT='%F %T `whoami` '
elif [[ -n "$ZSH_VERSION" ]]; then
    setopt promptsubst
    setopt hist_ignore_all_dups
    setopt hist_ignore_space
    setopt hist_reduce_blanks
    setopt hist_fcntl_lock 2>/dev/null
    # modify default PROMPT
    if [[ "$PROMPT" =~ "^# " ]]; then
        PROMPT='%f%F{6}%(5~|%-1~/…/%3~|%4~)%f %F{green}>%f '
    fi
    if [[ ! -n "$RPROMPT" ]]; then
        RPROMPT='%F{red}%(?..%?)%f %F{yellow}%n@%l %F{15}%*%f'
    fi
fi

# ----------------------- export some env var -------------------------
# export HISTIGNORE='ls:curl:history'
export HISTSIZE=3000
export SAVEHIST=3000
export VISUAL=vim
export EDITOR=vim

local_inc=$HOME/.local/include
if [ -d $local_inc ]; then
    [[ ! $C_INCLUDE_PATH =~ $local_inc ]] && export C_INCLUDE_PATH=$C_INCLUDE_PATH:$local_inc
    [[ ! $CPLUS_INCLUDE_PATH =~ $local_inc ]] && export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:$local_inc
fi
unset local_inc

