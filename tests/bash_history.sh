#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
home_dir="$tmpdir/home"
cache_dir="$tmpdir/cache"
mkdir -p "$home_dir"

bash "$repo_root/common.sh.in" stdout > "$generated"

HOME="$home_dir" XDG_CACHE_HOME="$cache_dir" GENERATED="$generated" \
    bash --noprofile --norc -c '
    set -euo pipefail
    source "$GENERATED"
    [[ $HISTFILE == "$XDG_CACHE_HOME/.bash_history" ]]
    [[ -d $XDG_CACHE_HOME ]]
    '
