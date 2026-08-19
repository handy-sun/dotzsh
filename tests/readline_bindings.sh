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
        bind -q shell-backward-kill-word
    ' 2>/dev/null)"

[[ "$binding_output" == *'shell-backward-kill-word can be found on "\\C-w".'* ]]
