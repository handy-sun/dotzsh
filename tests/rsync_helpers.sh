#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
zsh_bin="$(command -v zsh)"
bin_dir="$tmpdir/bin"
generated_sh="$tmpdir/common.sh"
generated_fish="$tmpdir/common.fish"
rsync_log="$tmpdir/rsync.log"

mkdir -p "$bin_dir"
for command_name in awk bash cat dirname ls mkdir mv readlink uname; do
    ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
done
ln -s "$repo_root/tests/fixtures/rsync" "$bin_dir/rsync"

PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated_sh"
PATH="$bin_dir" "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated_fish"

PATH="$bin_dir" GENERATED="$generated_sh" MOCK_RSYNC_LOG="$rsync_log" \
    "$bash_bin" --noprofile --norc -c 'source "$GENERATED"; rsyca "/source path/" "/destination path"'

PATH="$bin_dir" GENERATED="$generated_sh" MOCK_RSYNC_LOG="$rsync_log" \
    "$zsh_bin" -d -f -c '
        autoload -Uz compinit
        compinit -d "'$tmpdir'/zcompdump"
        source "$GENERATED"
        rsyca "/source path/" "/destination path"
    '

PATH="$bin_dir" GENERATED="$generated_fish" MOCK_RSYNC_LOG="$rsync_log" \
    "$fish_bin" --no-config -c 'source "$GENERATED"; rsyca "/source path/" "/destination path"'

expected='[-aHAX][--numeric-ids][--info=progress2][/source path/][/destination path]'
actual_count="$(rg -Fxc "$expected" "$rsync_log" || true)"
if [[ "$actual_count" -ne 3 ]]; then
    printf 'unexpected rsyca invocation count: expected 3, got %s\n' "$actual_count" >&2
    printf 'recorded invocations:\n' >&2
    cat "$rsync_log" >&2
    exit 1
fi
