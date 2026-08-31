#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
zsh_bin="$(command -v zsh)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

HOME="$tmpdir/home" REPO_ROOT="$repo_root" "$zsh_bin" -d -f -c '
    setopt localoptions no_aliases
    source "$REPO_ROOT/zsh-config.zsh"

    (( ${+functions[_dotzsh_zsh_prompt_pwd]} ))

    HOME="$HOME"
    PWD=/var/log/journal
    [[ $(_dotzsh_zsh_prompt_pwd) == "/v/l/journal" ]]

    PWD="$HOME/Projects/expnix"
    [[ $(_dotzsh_zsh_prompt_pwd) == "~/P/expnix" ]]

    PWD="$HOME/.config/codex"
    [[ $(_dotzsh_zsh_prompt_pwd) == "~/.c/codex" ]]

    PWD="$HOME/Projects/expnix"
    pre_set_prompt
    [[ $PROMPT == *"~/P/expnix"* ]]

    PWD=/
    [[ $(_dotzsh_zsh_prompt_pwd) == "/" ]]
'
