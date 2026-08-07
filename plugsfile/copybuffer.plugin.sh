# shellcheck shell=bash
# Copy the active command line, or the latest history entry, to the clipboard.

copybuffer() {
    local buf
    if [[ -n ${BASH_VERSION:-} ]]; then
        buf=${READLINE_LINE:-}
    else
        buf=${BUFFER:-}
    fi

    if [[ -z $buf ]]; then
        buf=$(fc -ln -1 2>/dev/null) || {
            printf 'No command line or history entry to copy.\n' >&2
            return 1
        }
    fi

    local copycmd
    if ! copycmd=$(getcopycmd); then
        if [[ -n ${ZSH_VERSION:-} && -n ${WIDGET:-} ]]; then
            zle -M "Clipboard copy program not found."
        fi
        return 1
    fi

    printf '%s' "$buf" | eval "$copycmd"
}

if [[ -n ${ZSH_VERSION:-} ]]; then
    zle -N copybuffer
    bindkey -M emacs "^O" copybuffer
    bindkey -M viins "^O" copybuffer
    bindkey -M vicmd "^O" copybuffer
elif [[ $- == *i* ]]; then
    bind -x '"\C-o":copybuffer'
fi
