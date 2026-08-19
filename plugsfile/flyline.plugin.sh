# shellcheck shell=bash
# shellcheck disable=SC2034
# Keep Flyline's Bash prompt integration separate from the shared prompt code.

if [[ -z ${BASH_VERSION:-} ]]; then
    return 0
fi

_dotzsh_bash_prompt_hook() {
    local exitStatus=$1
    local promFg=$2
    local shortPwd=$3

    [[ -n ${FLYLINE_VERSION:-} ]] || return 1
    _dotzsh_flyline_setup || return 1

    if (( EUID == 0 )); then
        _dotzsh_bash_prompt_prefix="#"
    elif [[ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}" ]]; then
        _dotzsh_bash_prompt_prefix=">>"
    else
        _dotzsh_bash_prompt_prefix=">"
    fi

    _dotzsh_bash_prompt_path=$shortPwd
    _dotzsh_bash_prompt_status_fg=$promFg
    if (( exitStatus == 0 )); then
        _dotzsh_bash_prompt_status=""
    else
        _dotzsh_bash_prompt_status="${exitStatus} "
    fi

    local jobCount
    jobCount=$(jobs -p | wc -l)
    if (( jobCount > 0 )); then
        _dotzsh_bash_prompt_jobs="%${jobCount} "
    else
        _dotzsh_bash_prompt_jobs=""
    fi

    if [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]]; then
        _dotzsh_bash_prompt_ssh="${USER:-${LOGNAME:-user}}@${HOSTNAME:-$(hostname)} "
    else
        _dotzsh_bash_prompt_ssh=""
    fi

    local shlvl_threshold=${DOTZSH_SHLVL_THRESHOLD:-1}
    [[ $shlvl_threshold =~ ^[0-9]+$ ]] || shlvl_threshold=1
    if [[ ${SHLVL:-} =~ ^[0-9]+$ ]] &&
        (( SHLVL > shlvl_threshold )); then
        _dotzsh_bash_prompt_shlvl="L${SHLVL}"
    else
        _dotzsh_bash_prompt_shlvl=""
    fi
}

_dotzsh_flyline_setup() {
    [[ -n ${_DOTZSH_FLYLINE_READY:-} ]] && return 0
    command -v flyline &>/dev/null || return 1

    flyline create-prompt-widget last-command-duration || return 1

    # Ctrl+W: delete one fine-grained word part — stops at punctuation and
    # path-segment boundaries (/ - . _ etc.) instead of Flyline's default
    # whitespace-delimited deleteLeftOneWord, matching zsh's WORDCHARS-tuned
    # backward-kill-word (zsh-config.zsh) and fish's precise word deletion.
    flyline key bind Ctrl+w always=deleteLeftOneWordPart &>/dev/null || true

    # Keep the Bash prompt aligned with zsh-config.zsh's left/right prompt.
    PS1='\e[0;36m${_dotzsh_bash_prompt_path}\e[0m \e[0;${_dotzsh_bash_prompt_status_fg}m${_dotzsh_bash_prompt_status}\e[1m${_dotzsh_bash_prompt_prefix}\e[0m '
    RPS1='\e[0;36mFLYLINE_LAST_COMMAND_DURATION\e[0m ${_dotzsh_bash_prompt_jobs}${_dotzsh_bash_prompt_ssh}\e[0;245m\A\e[0m \e[0;33mFLYLINE_PROMPT_LINE_NUMBER\e[0m\e[93;1m${_dotzsh_bash_prompt_shlvl}\e[0m'
    PS1_FILL=' '
    PS2='\e[0;33mFLYLINE_PROMPT_LINE_NUMBER>\e[0m '

    PS1_FINAL='\e[2m${_dotzsh_bash_prompt_prefix}\e[0m '
    RPS1_FINAL=""
    PS1_FILL_FINAL=""
    PROMPT_RULER_FINAL=""

    _DOTZSH_FLYLINE_READY=1
}
