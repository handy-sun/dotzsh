#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
bash "$repo_root/common.sh.in" stdout > "$generated"

binding_output="$(HOME="$tmpdir/home" GENERATED="$generated" \
    LC_ALL=C bash --noprofile --norc -ic '
        source "$GENERATED"
        bind -p
    ' 2>/dev/null)"

grep -Fq '"\C-w": unix-filename-rubout' <<< "$binding_output"

noninteractive_stderr="$(
    HOME="$tmpdir/home" GENERATED="$generated" \
        bash --noprofile --norc -c 'source "$GENERATED"' 2>&1 >/dev/null
)"
[[ -z "$noninteractive_stderr" ]]
