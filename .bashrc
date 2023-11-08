## define some func,alias,variable in zsh/bash shell script
# ----------------------- shell function ----------------------
dus() {
	du $1 -alh -d1 | sort -rh | head -n 11
}
# get real network device local ipv4 address
rlip4() {
	ip -o -4 addr list | grep -Ev '\s(docker|lo)' | awk '{print $4}' | cut -d/ -f1
}

# other shell
export LS_OPTIONS="--color=auto"
alias ls="ls $LS_OPTIONS"
alias ll="ls -AlF"
alias lh="ls -AlFh"
alias la="ls -alF"

# tar
alias tarx="tar --no-same-owner -xf"
alias tarz="tar zcf"

alias grep >/dev/null 2>&1 || alias grep="grep --color=auto"

# only bash use this PS1.
echo $SHELL | grep -E '/bash$' >/dev/null 2>&1
if [ $? -eq 0 ]; then
	last_exit_code="\$(LEC=\$? ; [[ \$LEC -ne 0 ]] && printf \"\033[91m%d \033[0m\" \$LEC)"
	PS1="\[\e[0m\]\[\033[0;32m\]\A \[\033[00;34m\]\h \[\033[0;36m\]\w\[\e[0m\] ${last_exit_code}\\$ "
	unset last_exit_code
fi

# ----------------------- export some env var -------------------------
export HISTTIMEFORMAT='%F %T '
