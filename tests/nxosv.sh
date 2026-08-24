#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
generated_sh="$tmpdir/common.sh"
generated_fish="$tmpdir/common.fish"
generated_fish_greeting="$tmpdir/common-greeting.fish"

"$bash_bin" "$repo_root/common.sh.in" stdout > "$generated_sh"
"$bash_bin" "$repo_root/common.fish.in" -0 > "$generated_fish"
"$bash_bin" "$repo_root/common.fish.in" -0g > "$generated_fish_greeting"

strip_colors() {
    local output=$1
    output=${output//$'\033[34m'/}
    output=${output//$'\033[36m'/}
    output=${output//$'\033[33m'/}
    output=${output//$'\033[90m'/}
    output=${output//$'\033[0m'/}
    output=${output//$'\033[m'/}
    printf '%s' "$output"
}

sh_output="$({
    GENERATED="$generated_sh" "$bash_bin" --noprofile --norc -c '
        compdef() { :; }
        source "$GENERATED"
        readlink() {
            case "$*" in
                "-f /run/current-system")
                    printf "%s\n" /nix/store/abc123-nixos-system-testhost-26.11
                    ;;
                "/nix/var/nix/profiles/system")
                    printf "%s\n" system-42-link
                    ;;
                *)
                    return 1
                    ;;
            esac
        }
        nix() {
            [[ $1 == --version ]] || return 1
            printf "%s\n" "nix (Nix) 9.9"
        }
        unset IN_NIX_SHELL DIRENV_DIR
        nxosv
    '
} 2>&1)"

fish_output="$({
    GENERATED="$generated_fish" "$fish_bin" --no-config -c '
        source "$GENERATED"
        function readlink
            switch (string join " " -- $argv)
                case "-f /run/current-system"
                    printf "%s\n" /nix/store/abc123-nixos-system-testhost-26.11
                case "/nix/var/nix/profiles/system"
                    printf "%s\n" system-42-link
                case "*"
                    return 1
            end
        end
        function nix
            test "$argv[1]" = --version; or return 1
            printf "%s\n" "nix (Nix) 9.9"
        end
        set -e IN_NIX_SHELL DIRENV_DIR
        nxosv
    '
} 2>&1)"

expected='❄️ Derivation: nixos-system-testhost-26.11 | Generation: 42 | (Nix) 9.9'
[[ "$(strip_colors "$sh_output")" == "$expected" ]]
[[ "$(strip_colors "$fish_output")" == "$expected" ]]

delegated="$({
    GENERATED="$generated_fish_greeting" "$fish_bin" --no-config -c '
        source "$GENERATED"
        function nxosv
            printf delegated
        end
        fish_greeting
    '
} 2>&1)"
[[ "$delegated" == delegated ]]
