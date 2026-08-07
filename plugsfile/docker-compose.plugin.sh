# shellcheck shell=bash
# Shared Bash/Zsh docker-compose helpers.
if ! command -v docker-compose &>/dev/null; then
    return 0
fi

if [[ -z ${DKCP_DIR:-} ]]; then
    if [ -d "/var/dkcmpo" ]; then
        export DKCP_DIR=/var/dkcmpo
    else
        export DKCP_DIR="$HOME/.local/share/dkcmpo"
        mkdir -p "$DKCP_DIR"
    fi
fi

_dotzsh_dcp_file() {
    local caller_name=$1
    shift
    if [[ $# -ne 1 || -z ${1:-} ]]; then
        printf 'Usage: %s <service>\n' "$caller_name" >&2
        return 2
    fi

    local dcp_file="$DKCP_DIR/$1/docker-compose.yml"
    if [[ ! -f $dcp_file ]]; then
        printf 'Error: %s not found\n' "$dcp_file" >&2
        return 1
    fi

    printf '%s\n' "$dcp_file"
}

dcpupd() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcpupd "$@") || return
    docker-compose -f "$dcp_file" up -d
}

dcpfru() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcpfru "$@") || return
    docker-compose -f "$dcp_file" up -d --force-recreate --remove-orphans
}

dcpdown() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcpdown "$@") || return
    docker-compose -f "$dcp_file" down --remove-orphans
}

dcpte() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcpte "$@") || return
    docker-compose -f "$dcp_file" stop
}

dcprs() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcprs "$@") || return
    docker-compose -f "$dcp_file" restart
}

dcppl() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcppl "$@") || return
    docker-compose -f "$dcp_file" pull
}

dcppal() {
    local dcp_file
    if [[ -n ${ZSH_VERSION:-} ]]; then
        setopt local_options null_glob
    fi
    for dcp_file in "$DKCP_DIR"/*/docker-compose.yml; do
        [[ -f $dcp_file ]] || continue
        if ! grep -iq 'restart: no' "$dcp_file"; then
            docker-compose -f "$dcp_file" pull
        fi
    done
}

dcpca() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcpca "$@") || return
    if command -v bat &>/dev/null; then
        bat "$dcp_file"
    else
        cat "$dcp_file"
    fi
}

dcped() {
    local dcp_file
    dcp_file=$(_dotzsh_dcp_file dcped "$@") || return
    local editor=${EDITOR:-vi}
    "$editor" "$dcp_file"
}
