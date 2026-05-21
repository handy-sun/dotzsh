#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.fish"
bash "$repo_root/common.fish.in" -0 > "$generated"

fish_home="$tmpdir/home"
fish_config="$fish_home/.config"
mkdir -p "$fish_config/fish"

transient_after="$(
    HOME="$fish_home" XDG_CONFIG_HOME="$fish_config" GENERATED_COMMON_FISH="$generated" fish -c '
        source "$GENERATED_COMMON_FISH"

        function tide
            set --universal tide_prompt_transient_enabled false
        end

        set --universal tide_prompt_transient_enabled true
        dotzsh_tide lean2
        echo $tide_prompt_transient_enabled
    '
)"

if [[ "$transient_after" != "true" ]]; then
    printf 'expected lean2 to preserve transient setting, got: %s\n' "$transient_after" >&2
    exit 1
fi

if ! grep -q 'echo "  lean2' "$generated"; then
    printf 'expected lean2 to be listed in dotzsh_tide help\n' >&2
    exit 1
fi

if ! grep -q 'complete -c dotzsh_tide .* lean2 ' "$generated"; then
    printf 'expected lean2 to be listed in dotzsh_tide completions\n' >&2
    exit 1
fi
