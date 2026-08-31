#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
bash "$repo_root/common.sh.in" stdout > "$generated"

HOME="$tmpdir/home" GENERATED="$generated" TMPROOT="$tmpdir" \
    bash --noprofile --norc -c '
    set -euo pipefail
    source "$GENERATED"

    pwd() { printf "%s\\n" "$TEST_PWD"; }

    TEST_PWD=/var/log/journal
    [[ $(_get_short_pwd) == "/v/l/journal" ]]

    TEST_PWD="$HOME/Projects/expnix"
    [[ $(_get_short_pwd) == "~/P/expnix" ]]

    TEST_PWD="$HOME/.config/codex"
    [[ $(_get_short_pwd) == "~/.c/codex" ]]

    TEST_PWD=/
    [[ $(_get_short_pwd) == "/" ]]
    '
