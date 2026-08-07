# shellcheck shell=bash
# Copy a path to the system clipboard. Use the current directory by default.

copypath() {
    local file="${1:-.}"
    if [[ $file == . ]]; then
        file=$PWD
    elif [[ $file != /* ]]; then
        file="$PWD/$file"
    fi

    local normalized_file
    if normalized_file=$(realpath -s -- "$file" 2>/dev/null); then
        file=$normalized_file
    fi

    local copycmd
    copycmd=$(getcopycmd) || return 1

    printf '%s' "$file" | eval "$copycmd" || return 1

    printf '\033[1m%s\033[0m copied to clipboard.\n' "$file"
}
