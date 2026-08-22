#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
zsh_bin="$(command -v zsh)"
generated="$tmpdir/common.sh"
localpost_dir="$tmpdir/home/.cache/dotzsh/localpost"

mkdir -p "$localpost_dir"
cp "$repo_root/tests/fixtures/localpost-marker.sh" "$localpost_dir/10-marker.sh"

"$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"

HOME="$tmpdir/home" GENERATED="$generated" \
    "$bash_bin" --noprofile --norc -c '
        source "$GENERATED"
        [[ ${DOTZSH_LOCALPOST_BASH:-} == loaded ]]
    '

HOME="$tmpdir/home" GENERATED="$generated" ZCOMPDUMP="$tmpdir/zcompdump" \
    "$zsh_bin" -d -f -c '
        autoload -Uz compinit
        compinit -d "$ZCOMPDUMP"
        source "$GENERATED"
        [[ ${DOTZSH_LOCALPOST_BASH:-} == loaded ]]
    '
