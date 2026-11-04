#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
zsh_bin="$(command -v zsh)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated_sh="$tmpdir/common.sh"
bash "$repo_root/common.sh.in" stdout > "$generated_sh"

IN_NIX_SHELL=pure GENERATED="$generated_sh" bash --noprofile --norc -c '
    set -euo pipefail
    source "$GENERATED"
    [[ $(_dotzsh_nix_shell_prompt) == "pure " ]]
    unset IN_NIX_SHELL
    [[ -z $(_dotzsh_nix_shell_prompt) ]]
'

IN_NIX_SHELL=impure REPO_ROOT="$repo_root" GENERATED="$generated_sh" \
    "$zsh_bin" -d -f -c '
    set -e
    source "$REPO_ROOT/zsh-config.zsh"
    source "$GENERATED"
    pre_set_prompt
    [[ $RPROMPT == *"%F{#7EBAE4}impure %f"* ]]
    unset IN_NIX_SHELL
    pre_set_prompt
    [[ $RPROMPT != *"nix:"* ]]

    # Suspended jobs raise the %<n> badge; running background jobs do not.
    [[ $RPROMPT != *"%%"* ]]
    sleep 100 &
    sleep 0.2
    pre_set_prompt
    [[ $RPROMPT != *"%%"* ]]
    kill -STOP %1
    sleep 0.2
    pre_set_prompt
    [[ $RPROMPT == *"%%1 "* ]]
    kill -KILL %1
    sleep 0.2
    pre_set_prompt
    [[ $RPROMPT != *"%%"* ]]
'
