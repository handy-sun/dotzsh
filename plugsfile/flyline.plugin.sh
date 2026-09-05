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
    _dotzsh_gitstatus_prompt

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

_dotzsh_gitstatus_setup() {
    if [[ ${_DOTZSH_GITSTATUS_ATTEMPTED:-0} == 1 ]]; then
        [[ ${_DOTZSH_GITSTATUS_READY:-0} == 1 ]]
        return
    fi
    _DOTZSH_GITSTATUS_ATTEMPTED=1

    local gitstatus_dir=${DOTZSH_GITSTATUS_DIR:-}
    if [[ -z $gitstatus_dir ]] && command -v gitstatus-share &>/dev/null; then
        gitstatus_dir=$(gitstatus-share 2>/dev/null) || gitstatus_dir=
    fi
    if [[ -r $gitstatus_dir/gitstatus.plugin.sh ]] &&
        source "$gitstatus_dir/gitstatus.plugin.sh" &&
        gitstatus_start -s -1 -u -1 -c -1 -d -1; then
        _DOTZSH_GITSTATUS_BACKEND=gitstatus
        _DOTZSH_GITSTATUS_READY=1
        return 0
    fi

    if command -v git &>/dev/null; then
        _DOTZSH_GITSTATUS_BACKEND=fallback
        _DOTZSH_GITSTATUS_READY=1
        return 0
    fi

    _DOTZSH_GITSTATUS_READY=0
    return 1
}

_dotzsh_git_fallback_query() {
    VCS_STATUS_RESULT=norepo-sync
    VCS_STATUS_LOCAL_BRANCH=
    VCS_STATUS_TAG=
    VCS_STATUS_COMMIT=
    VCS_STATUS_COMMITS_AHEAD=0
    VCS_STATUS_COMMITS_BEHIND=0
    VCS_STATUS_PUSH_COMMITS_AHEAD=0
    VCS_STATUS_PUSH_COMMITS_BEHIND=0
    VCS_STATUS_STASHES=0
    VCS_STATUS_ACTION=
    VCS_STATUS_NUM_CONFLICTED=0
    VCS_STATUS_NUM_STAGED=0
    VCS_STATUS_NUM_UNSTAGED=0
    VCS_STATUS_NUM_UNTRACKED=0

    local line record xy ahead behind
    while IFS= read -r line; do
        case $line in
        '# branch.oid '*) VCS_STATUS_COMMIT=${line#\# branch.oid } ;;
        '# branch.head '*) VCS_STATUS_LOCAL_BRANCH=${line#\# branch.head } ;;
        '# branch.ab '*)
            read -r _ _ ahead behind <<< "$line"
            VCS_STATUS_COMMITS_AHEAD=${ahead#+}
            VCS_STATUS_COMMITS_BEHIND=${behind#-}
            ;;
        '# stash '*) VCS_STATUS_STASHES=${line#\# stash } ;;
        '1 '*|'2 '*)
            read -r record xy _ <<< "$line"
            [[ ${xy:0:1} == . ]] || ((VCS_STATUS_NUM_STAGED += 1))
            [[ ${xy:1:1} == . ]] || ((VCS_STATUS_NUM_UNSTAGED += 1))
            ;;
        'u '*) ((VCS_STATUS_NUM_CONFLICTED += 1)) ;;
        '? '*) ((VCS_STATUS_NUM_UNTRACKED += 1)) ;;
        esac
    done < <(git status --porcelain=v2 --branch --show-stash 2>/dev/null) || return 1

    [[ -n $VCS_STATUS_COMMIT ]] || return 1
    [[ $VCS_STATUS_LOCAL_BRANCH == '(detached)' ]] && VCS_STATUS_LOCAL_BRANCH=
    VCS_STATUS_RESULT=ok-sync
}

_dotzsh_gitstatus_prompt() {
    _dotzsh_bash_prompt_gitstatus=
    [[ ${_DOTZSH_GITSTATUS_READY:-0} == 1 ]] || return 0
    if [[ ${_DOTZSH_GITSTATUS_BACKEND:-} == gitstatus ]]; then
        gitstatus_query || return 0
    else
        _dotzsh_git_fallback_query || return 0
    fi
    [[ ${VCS_STATUS_RESULT:-} == ok-sync ]] || return 0

    local reset=$'\e[0m'
    local clean=$'\e[38;5;076m'
    local untracked=$'\e[38;5;014m'
    local modified=$'\e[38;5;011m'
    local conflicted=$'\e[38;5;196m'
    local where=${VCS_STATUS_LOCAL_BRANCH:-}
    local prompt=

    if [[ -n $where ]]; then
        :
    elif [[ -n ${VCS_STATUS_TAG:-} ]]; then
        prompt+='#'
        where=$VCS_STATUS_TAG
    else
        prompt+='@'
        where=${VCS_STATUS_COMMIT:0:8}
    fi
    (( ${#where} > 32 )) && where="${where:0:12}…${where: -12}"
    prompt+="${clean}${where}"

    (( ${VCS_STATUS_COMMITS_BEHIND:-0} )) && prompt+="${clean}⇣${VCS_STATUS_COMMITS_BEHIND}"
    (( ${VCS_STATUS_COMMITS_AHEAD:-0} )) && prompt+="${clean}⇡${VCS_STATUS_COMMITS_AHEAD}"
    (( ${VCS_STATUS_PUSH_COMMITS_BEHIND:-0} )) && prompt+="${clean}⇠${VCS_STATUS_PUSH_COMMITS_BEHIND}"
    (( ${VCS_STATUS_PUSH_COMMITS_AHEAD:-0} )) && prompt+="${clean}⇢${VCS_STATUS_PUSH_COMMITS_AHEAD}"
    (( ${VCS_STATUS_STASHES:-0} )) && prompt+="${clean}*${VCS_STATUS_STASHES}"
    [[ -n ${VCS_STATUS_ACTION:-} ]] && prompt+="${conflicted}${VCS_STATUS_ACTION}"
    (( ${VCS_STATUS_NUM_CONFLICTED:-0} )) && prompt+="${conflicted}~${VCS_STATUS_NUM_CONFLICTED}"
    (( ${VCS_STATUS_NUM_STAGED:-0} )) && prompt+="${modified}+${VCS_STATUS_NUM_STAGED}"
    (( ${VCS_STATUS_NUM_UNSTAGED:-0} )) && prompt+="${modified}!${VCS_STATUS_NUM_UNSTAGED}"
    (( ${VCS_STATUS_NUM_UNTRACKED:-0} )) && prompt+="${untracked}?${VCS_STATUS_NUM_UNTRACKED}"

    _dotzsh_bash_prompt_gitstatus="${prompt}${reset} "
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

    # Use gitstatusd for fast Git state queries without replacing Flyline's prompt.
    _dotzsh_gitstatus_setup || true

    # Keep the Bash prompt aligned with zsh-config.zsh's left/right prompt.
    PS1='\e[0;36m${_dotzsh_bash_prompt_path}\e[0m \e[0;${_dotzsh_bash_prompt_status_fg}m${_dotzsh_bash_prompt_status}\e[1m${_dotzsh_bash_prompt_prefix}\e[0m '
    RPS1='\e[0;36mFLYLINE_LAST_COMMAND_DURATION\e[0m ${_dotzsh_bash_prompt_gitstatus}\e[38;2;126;186;228m${_dotzsh_bash_prompt_nix_shell}\e[0m${_dotzsh_bash_prompt_jobs}${_dotzsh_bash_prompt_ssh}\e[38;5;245m\A\e[0m \e[0;33mFLYLINE_PROMPT_LINE_NUMBER\e[0m\e[93;1m${_dotzsh_bash_prompt_shlvl}\e[0m'
    PS1_FILL=' '
    PS2='\e[0;33mFLYLINE_PROMPT_LINE_NUMBER>\e[0m '

    PS1_FINAL='\e[2m${_dotzsh_bash_prompt_prefix}\e[0m '
    RPS1_FINAL=""
    PS1_FILL_FINAL=""
    PROMPT_RULER_FINAL=""

    _DOTZSH_FLYLINE_READY=1
}
