#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
zsh_bin="$(command -v zsh)"
bin_dir="$tmpdir/bin"
generated="$tmpdir/common.sh"
zoxide_log="$tmpdir/zoxide.log"

mkdir -p "$bin_dir"
for command_name in awk bash cat dirname ls mkdir mv readlink uname; do
    ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
done
ln -s "$repo_root/tests/fixtures/zoxide" "$bin_dir/zoxide"

PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"

PATH="$bin_dir" GENERATED="$generated" MOCK_ZOXIDE_LOG="$zoxide_log" \
    "$bash_bin" --noprofile --norc -c '
        source "$GENERATED"
        [[ ${ZOXIDE_BASH_INITIALIZED:-} == 1 ]]
    '

PATH="$bin_dir" GENERATED="$generated" MOCK_ZOXIDE_LOG="$zoxide_log" ZCOMPDUMP="$tmpdir/zcompdump" \
    "$zsh_bin" -d -f -c '
        autoload -Uz compinit
        compinit -d "$ZCOMPDUMP"
        source "$GENERATED"
        [[ -z ${ZOXIDE_BASH_INITIALIZED:-} ]]
    '

PATH=/nonexistent GENERATED="$generated" \
    "$bash_bin" --noprofile --norc -c 'source "$GENERATED"'

expected='[init][bash]'
actual_count="$(rg -Fxc "$expected" "$zoxide_log" || true)"
if [[ "$actual_count" -ne 1 ]]; then
    printf 'unexpected zoxide invocation count: expected 1, got %s\n' "$actual_count" >&2
    printf 'recorded invocations:\n' >&2
    cat "$zoxide_log" >&2
    exit 1
fi
