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

items="$(
    HOME="$fish_home" XDG_CONFIG_HOME="$fish_config" GENERATED_COMMON_FISH="$generated" fish -c '
        source "$GENERATED_COMMON_FISH"
        set --universal _tide_right_items status time
        set --erase tide_right_prompt_items
        dotzsh_tide ar shlvl proxy private_mode shlvl >/dev/null
        string join "," $_tide_right_items
        string join "," $tide_right_prompt_items
        true
    '
)"

expected_items=$'status,time,shlvl,proxy,private_mode\nstatus,time,shlvl,proxy,private_mode'
if [[ "$items" != "$expected_items" ]]; then
    printf 'expected ar to append unique right prompt items, got:\n%s\n' "$items" >&2
    exit 1
fi

missing_operand="$(
    HOME="$fish_home" XDG_CONFIG_HOME="$fish_config" GENERATED_COMMON_FISH="$generated" fish -c '
        source "$GENERATED_COMMON_FISH"
        dotzsh_tide ar
        echo status:$status
    '
)"

expected_missing_operand=$'Usage: dotzsh_tide ar <item> [item ...]\nstatus:1'
if [[ "$missing_operand" != "$expected_missing_operand" ]]; then
    printf 'expected ar to reject missing operands, got:\n%s\n' "$missing_operand" >&2
    exit 1
fi

if ! grep -q 'echo "  ar <item> \[item ...\]' "$generated"; then
    printf 'expected ar to be listed in dotzsh_tide help\n' >&2
    exit 1
fi

if ! grep -q 'complete -c dotzsh_tide .*"ar ' "$generated"; then
    printf 'expected ar to be listed in dotzsh_tide completions\n' >&2
    exit 1
fi
