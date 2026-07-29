#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
true_bin="$(type -P true)"

make_bin() {
    local case_name=$1
    shift
    local bin_dir="$tmpdir/bin-$case_name"
    mkdir -p "$bin_dir"

    local command_name
    for command_name in bash cat dirname ls readlink uname; do
        ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
    done

    cp "$repo_root/tests/fixtures/pkg-id" "$bin_dir/id"
    chmod +x "$bin_dir/id"

    for command_name in "$@"; do
        ln -s "$true_bin" "$bin_dir/$command_name"
    done

    printf '%s\n' "$bin_dir"
}

generate_config() {
    local shell_name=$1
    local case_name=$2
    local bin_dir=$3
    local uid=$4
    local generated="$tmpdir/common-$shell_name-$case_name"

    if [[ "$shell_name" == sh ]]; then
        PATH="$bin_dir" MOCK_UID="$uid" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"
    else
        PATH="$bin_dir" MOCK_UID="$uid" "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated"
    fi

    printf '%s\n' "$generated"
}

assert_line() {
    local expected=$1
    local generated=$2
    local context=$3

    if ! rg -Fqx "$expected" "$generated"; then
        printf 'missing generated alias for %s:\n%s\n' "$context" "$expected" >&2
        return 1
    fi
}

run_case() {
    local case_name=$1
    local uid=$2
    local command_list=$3
    shift 3

    local -a command_names
    read -r -a command_names <<< "$command_list"

    local bin_dir
    bin_dir="$(make_bin "$case_name" "${command_names[@]}")"

    local shell_name generated expected
    for shell_name in sh fish; do
        generated="$(generate_config "$shell_name" "$case_name" "$bin_dir" "$uid")"
        for expected in "$@"; do
            assert_line "$expected" "$generated" "$shell_name/$case_name"
        done
    done
}

run_case apt-sudo 1000 'apt sudo' \
    'alias pkgsy="sudo apt install -y"' \
    'alias pkgr="sudo apt remove"' \
    'alias pkgss="apt search"'

run_case apt-doas 1000 'apt doas' \
    'alias pkgsy="doas apt install -y"' \
    'alias pkgr="doas apt remove"' \
    'alias pkgss="apt search"'

run_case apt-no-helper 1000 'apt' \
    'alias pkgsy="apt install -y"' \
    'alias pkgr="apt remove"'

run_case apt-root 0 'apt sudo' \
    'alias pkgsy="apt install -y"' \
    'alias pkgr="apt remove"'

run_case pacman-sudo 1000 'pacman sudo' \
    'alias pkgsy="sudo pacman -S --noconfirm"' \
    'alias pkgr="sudo pacman -R"' \
    'alias pkgss="pacman -Ss"'

run_case pacman-yay 1000 'pacman sudo yay' \
    'alias pkgsy="yay -S --noconfirm"' \
    'alias pkgr="yay -R"' \
    'alias pkgss="yay -Ss"'

run_case pacman-paru 1000 'pacman doas paru' \
    'alias pkgsy="paru -S --noconfirm"' \
    'alias pkgr="paru -R"' \
    'alias pkgss="paru -Ss"'

run_case apk-sudo 1000 'apk sudo' \
    'alias pkgsy="sudo apk add"' \
    'alias pkgr="sudo apk del"' \
    'alias pkgss="apk search"'

run_case brew-sudo 1000 'brew sudo' \
    'alias pkgsy="brew install"' \
    'alias pkgr="brew uninstall"' \
    'alias pkgss="brew search"'
