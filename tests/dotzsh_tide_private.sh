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
        set --universal _tide_left_items os pwd git
        set --erase tide_left_prompt_items
        dotzsh_tide addl-private >/dev/null
        dotzsh_tide addl-private >/dev/null
        string join "," $_tide_left_items
        string join "," $tide_left_prompt_items
        true
    '
)"

expected_items=$'private,os,pwd,git\nprivate,os,pwd,git'
if [[ "$items" != "$expected_items" ]]; then
    printf 'expected private item to be first and idempotent, got:\n%s\n' "$items" >&2
    exit 1
fi

private_output="$(
    HOME="$fish_home" XDG_CONFIG_HOME="$fish_config" GENERATED_COMMON_FISH="$generated" fish --private -c '
        source "$GENERATED_COMMON_FISH"
        string join "," $_tide_left_items
        _tide_item_private | string trim
    '
)"

expected_private_output=$'private,os,pwd,git\n🔒'
if [[ "$private_output" != "$expected_private_output" ]]; then
    printf 'expected private mode to keep private item first and show symbol, got:\n%s\n' "$private_output" >&2
    exit 1
fi

normal_symbol="$(
    HOME="$fish_home" XDG_CONFIG_HOME="$fish_config" GENERATED_COMMON_FISH="$generated" fish -c '
        source "$GENERATED_COMMON_FISH"
        _tide_item_private | string collect
        true
    '
)"

if [[ -n "$normal_symbol" ]]; then
    printf 'expected no private prompt symbol outside private mode, got: %s\n' "$normal_symbol" >&2
    exit 1
fi
