# shellcheck shell=bash
# Colorize man pages in Bash and Zsh. See termcap(5).

colored() {
    local default_mb default_md default_me default_so default_se default_us default_ue
    if [[ -n ${ZSH_VERSION:-} ]]; then
        default_mb=${fg_bold[red]:-$'\033[1;31m'}
        default_md=${fg_bold[red]:-$'\033[1;31m'}
        default_me=${reset_color:-$'\033[0m'}
        default_so="${fg_bold[yellow]:-$'\033[1;33m'}${bg[blue]:-$'\033[44m'}"
        default_se=${reset_color:-$'\033[0m'}
        default_us=${fg_bold[green]:-$'\033[1;32m'}
        default_ue=${reset_color:-$'\033[0m'}
    else
        default_mb=$'\033[1;31m'
        default_md=$'\033[1;31m'
        default_me=$'\033[0m'
        default_so=$'\033[1;33;44m'
        default_se=$'\033[0m'
        default_us=$'\033[1;32m'
        default_ue=$'\033[0m'
    fi

    local -a environment=(
        "LESS_TERMCAP_mb=${LESS_TERMCAP_mb:-$default_mb}"
        "LESS_TERMCAP_md=${LESS_TERMCAP_md:-$default_md}"
        "LESS_TERMCAP_me=${LESS_TERMCAP_me:-$default_me}"
        "LESS_TERMCAP_so=${LESS_TERMCAP_so:-$default_so}"
        "LESS_TERMCAP_se=${LESS_TERMCAP_se:-$default_se}"
        "LESS_TERMCAP_us=${LESS_TERMCAP_us:-$default_us}"
        "LESS_TERMCAP_ue=${LESS_TERMCAP_ue:-$default_ue}"
        "GROFF_NO_SGR=1"
    )

    local pager=${PAGER:-}
    if command -v less &>/dev/null; then
        pager=$(command -v less)
    fi
    [[ -n $pager ]] && environment+=("PAGER=$pager")

    command env "${environment[@]}" "$@"
}

man() {
    colored man "$@"
}

dman() {
    colored dman "$@"
}

debman() {
    colored debman "$@"
}
