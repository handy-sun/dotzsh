## define some func,alias,variable in zsh/bash shell script
# ----------------------- shell function ----------------------
# Determine whether a command exists
cmd_exists() {
    command -v "$@" &>/dev/null
}
# about git stash
shpo() {
    git stash pop stash@{$1};
}
shap() {
    git stash apply stash@{$1};
}
shsw() {
    git stash show -p stash@{$1};
}
shdr() {
    git stash drop stash@{$1};
}
# get pid of a process, avoid some Linux system cannot use 'pgrep' program
qpid() {
    ps -eo pid,cmd | grep "$1" | grep -vE 'grep|\]$' | awk '{print$1;}'
}
# print all info, and search insensitive
ppre() {
    ps -ef | grep -i "$1" | grep -vE 'grep|\]$'
}
# final location of which command
fwh() {
    local yellow=$'\E[0;33m'
    local reset=$'\E[m'
    local whi=`\which $1 2>/dev/null`
    # is aliased to?
    if echo $whi | grep -q ' aliased '; then
        local real_cmd=`echo $whi | cut -d' ' -f4`
        local argu="`echo $whi | cut -d' ' -f5-`"
        if [[ "$1" == "$real_cmd" ]]; then
            [ -x /bin/$real_cmd ] && echo "/bin/$real_cmd ${yellow}with arguments:${reset} $argu $2"
        else
            fwh $real_cmd "$argu $2"
        fi
    else
        if [ -x ${whi} 2>/dev/null ]; then
            readlink -f ${whi} | xargs -I{} echo {} `test -n "$2" && echo "with arguments: $2"`
        elif echo $whi | grep -qE '}$'; then # shell function
            type $1
            echo "$whi"
        elif echo $whi | grep -q 'built-in'; then # shell built-in
            echo -e "${yellow}$whi${reset}"
        else
            echo -e "ERROR\n $whi"
        fi
    fi
}
htdel() {
    set -x
    if [[ -n "$HISTFILE" ]]; then
        local file=$HISTFILE
    elif [[ -n "$ZSH_VERSION" ]] && [ -e ~/.zhistory ]; then
        local file=~/.zhistory
    elif [[ -n "$BASH_VERSION" ]] && [ -e ~/.bash_history ]; then
        local file=~/.bash_history
    else
        return 1
    fi

    if [[ "$1" =~ "/" ]]; then
        transfer=`printf "$1" | sed 's#\/#\\\/#g'`
        sed -i "/$transfer/d" $file
    else
        sed -i "/$1/d" $file
    fi
}
# get real network device local ipv4 address
rlip4() {
    ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{printf"%-20s %s\n",$2,$4}'
}
# quickly update(rebase) git repo between local and all remotes
gitur() {
    set -x
    git add `git status -s | grep -vE '^\?\?|  ' | awk '{print$2;}'`
    [ $? -eq 0 ] || return 1

    git commit
    if ! git pull --rebase; then
        echo 'handle conflicts first!'
        return 1
    fi

    remote_arr=(`git remote`)
    for var in ${remote_arr[*]}; do
        git push --all $var
    done
}
jnl() {
    journalctl -eu $1 | less +G
}
jfxeu() {
    journalctl -n 100 -fxeu $1
}
dkcid() {
    docker ps -qf "name= $1\$"
}
dktty() {
    ctner_count=`dkcid $1 | wc -l`
    if [ $ctner_count -ne 1 ]; then
        echo "ERROR: $ctner_count container(s) found, cannot exec shell!";
        return 1
    fi
    shell_arr=("bash" "sh" "zsh" "fish" "ash")
    for var in ${shell_arr[*]}; do
        docker exec -ti $1 /bin/$var -i && return 0
    done
}
qip() {
    curl -S ip-api.com/json/$1 2>/dev/null | jq '.'
}
cdt() {
    if [[ ! -e $1 ]]; then
        echo "Error: The file or directory does not exist."
        return 1
    fi

    if [[ -d $1 ]]; then
        cd "$1"
    elif [[ -f $1 ]]; then
        cd "$(dirname "$1")"
    else
        echo "Error: Not a file or directory."
        return 1
    fi
}
upd() {
    local dir=""
    local limit="$1"
    for ((i=1; i <= limit; i++)); do
        dir="../$dir"
    done
    cd "$dir"
}

swap2file() {
    if [[ ! -f "$1" || ! -f "$2" ]]; then
        echo "$1 or $2 is not existed." >&2
        exit 1
    fi

    if [[ "$1" -ef "$2" ]]; then
        echo "$1 and $2 is same file" >&2
        exit 2
    fi

    tempfile=`mktemp ./swap2file.$$.XXXXXXXXXX`
    mv "$1" $tempfile
    mv "$2" "$1"
    mv $tempfile "$2"
}
dus() {
    du $1 --apparent-size -alh -d1 | sort -rh | head -n 21
}
qlibc() {
    strings $1 | grep -E '^GLIBC_'
}

# about bash prompt
_get_short_pwd() {
    split=5
    W=$(pwd | sed -e "s!$HOME!~!")
    total_cnt=$(echo $W | grep -o '/' | wc -l)
    last_cnt=$(($total_cnt-1))
    if [ $total_cnt -gt $split ]; then
        echo $W | cut -d/ -f1-2 | xargs -I{} echo {}"/…/$(echo $W | cut -d/ -f${last_cnt}-)"
    else
        echo $W
    fi
}

_get_jobs_name() {
    local job_arr=(`jobs | tr -d '+' | awk '$2 == "Stopped" || $2 == "suspended" {print$3}'`)
    local content=
    for var in ${job_arr[*]}; do
        content="${content}%${var} "
    done
    echo "${content}"
}

_bash_prompt_cmd() {
    [[ $? -eq 0 ]] && local promFg="92" || local promFg="91"
    local shortPwd=`_get_short_pwd`
    local jobIdx=`_get_jobs_name`
    PS1="\[\e[0m\]\[\033[0;32m\]\A \[\e[0;36m\]${shortPwd} \[\e[0;34m\]${jobIdx}\[\e[0m\]\[\e[0;${promFg}m\]\\$\[\e[0m\] "
}

# ----------------------- condition shell function ----------------------
# tar compress/uncompress gzip with pigz
if cmd_exists pigz; then
    tcpzf() {
        tar cf - $2 | pigz --fast > $1
    }
    txpz() {
        tar --no-same-owner -xf $1 -I pigz
    }
fi

if cmd_exists rsync; then
    cpv() {
        rsync -pogbr -hhh --backup-dir="/tmp/rsync-${USERNAME}" -e /dev/null --progress "$@"
    }
fi
# ----------------------- alias ---------------------- {{{1
# git
alias gta="git status"
alias gts="git status -s"
alias gtun="git status uno"

alias gcm="git commit"
alias gcmm="git commit -m"
alias gcma="git commit -a"
alias gcmam="git commit -a -m"
alias gcmn="git commit --amend"
alias gcman="git commit -a --amend"

alias gpl="git pull"
alias gplrb="git pull --rebase"

alias gsh="git stash"
alias gshl="git stash list"
alias gshp="git stash pop"

alias grs="git reset"
alias grsh="git reset --hard"
alias grss="git reset --soft"
alias gro="git restore"
alias grog="git restore --staged"

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

alias gchp="git cherry-pick"
alias gcln="git clean -n"
alias gclfd="git clean -fd"
# tar
alias tarx="tar --no-same-owner -xf"
alias tarz="tar zcf"

# systemctl
alias syta="systemctl status"
alias syca="systemctl cat"
alias syst="sudo systemctl start"
alias syrs="sudo systemctl restart"
alias syte="sudo systemctl stop"
alias syrld="sudo systemctl reload"
alias syen="sudo systemctl enable"
alias syenw="sudo systemctl enable --now"
alias sydis="sudo systemctl disable"
alias sydisw="sudo systemctl disable --now"
alias sydrld="sudo systemctl daemon-reload"

# cmake
export BUILD_DIR="./build"

alias cmkln="rm -rf ${BUILD_DIR}/CMakeCache.txt ${BUILD_DIR}/CMakeFiles/"
alias cmkr="cmake -B${BUILD_DIR} -G 'Ninja' -DCMAKE_BUILD_TYPE=Release"
alias cmkd="cmake -B${BUILD_DIR} -G 'Ninja' -DCMAKE_BUILD_TYPE=Debug"
alias cmba="cmake --build ${BUILD_DIR}"
alias cmbt="cmake --build ${BUILD_DIR} -t"

# docker
if cmd_exists perl; then
    alias dps="docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | perl -pe 's/, :::.*?p//g'"
else
    alias dps="docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
fi

alias dpz="docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}'"

# pacman (archlinux/manjaro)
if cmd_exists pacman; then
    if [ $(id -u) -eq 0 ]; then
        _cmd=pacman
    else
        if cmd_exists yay; then
            _cmd=yay
        elif cmd_exists paru; then
            _cmd=paru
        else
            _cmd=pacman
        fi
    fi

    alias pkgsy="$_cmd -Sy"
    alias pkgr="$_cmd -R"
    alias pkgssq="$_cmd -Ssq"
    alias pkgss="$_cmd -Ss"
    alias pkgsi="$_cmd -Si"
    alias pkgqs="$_cmd -Qs"
    alias pkgqi="$_cmd -Qi"
    alias pkgql="$_cmd -Ql"
    alias pkgqo="$_cmd -Qo"
fi
unset _cmd

[[ -z "$LS_OPTIONS" ]] && export LS_OPTIONS="--color=auto"
alias ls="ls -A $LS_OPTIONS"
alias ll="ls -AlFh"
alias l="ls -AlF"
alias la="ls -alF"

# other shell
alias r="fc -s"
alias pingk="ping -c4"
alias gdb="gdb -q"
alias cp="cp -arvf"
alias less="less -R"
alias df="df -Th"
alias free="free -h"
alias rrm="\rm -rf"

cmd_exists trash && alias rm="trash"
cmd_exists xclip && alias pbcopy="xclip -selection clipboard" && alias pbpaste="xclip -selection clipboard -o"
cmd_exists fd && alias fd="fd -HI"
cmd_exists tree && alias trelh="tree -AlFh" && alias treds="tree -hF --du --sort=size | more"

alias grep &>/dev/null || alias grep="grep --color=auto"
alias diff &>/dev/null || alias diff="diff --color=auto"
alias thupipins="pip install -i https://pypi.tuna.tsinghua.edu.cn/simple"
# alias }}}1

_PRE=$'\E['

PS2="${_PRE}0;33m>${_PRE}0m"
PS4="${_PRE}1;2m+${_PRE}0;33m$0:${_PRE}0;92m$LINENO${_PRE}m${_PRE}1;2m> ${_PRE}m"
unset _PRE

if [[ -n "$BASH_VERSION" ]]; then
    PROMPT_COMMAND=_bash_prompt_cmd
    HISTCONTROL=ignoreboth
    shopt -s histappend
    shopt -s autocd
    shopt -s checkwinsize
    shopt -s expand_aliases
    export HISTTIMEFORMAT='%F %T '
fi

# vim:fdm=marker
