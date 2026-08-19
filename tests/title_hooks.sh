#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
bash "$repo_root/common.sh.in" stdout > "$generated"

HOME="$tmpdir/home" GENERATED="$generated" bash --noprofile --norc -c '
    set -euo pipefail
    mkdir -p "$HOME/project"
    source "$GENERATED"
    cd "$HOME/project"

    idle="$(TERM=xterm-256color _dotzsh_title_precmd)"
    [[ "$idle" == $'"'"'\033]0;~/project\007'"'"' ]]

    running="$(TERM=xterm-256color _dotzsh_title_preexec "sleep 2")"
    [[ "$running" == $'"'"'\033]0;sleep 2:~/project\007'"'"' ]]

    running="$(TERM=tmux-256color _dotzsh_title_preexec "sleep 2")"
    [[ "$running" == $'"'"'\033ksleep 2:~/project\033\\'"'"' ]]

    running="$(TERM=xterm-256color _dotzsh_title_preexec $'"'"'printf bad\033]0;injected\007\ncommand'"'"')"
    [[ "$running" == $'"'"'\033]0;printf bad]0;injected command:~/project\007'"'"' ]]

    DISABLE_AUTO_TITLE=true
    [[ -z "$(_dotzsh_title_precmd)" ]]
    [[ -z "$(_dotzsh_title_preexec "sleep 2")" ]]
'

trap_output="$(
    HOME="$tmpdir/home" GENERATED="$generated" bash --noprofile --norc -ic '
        previous_debug_trap() {
            [[ -n ${CHECK_PREVIOUS_TRAP:-} ]] && PREVIOUS_TRAP_RAN=1
        }
        trap previous_debug_trap DEBUG
        source "$GENERATED"
        prompt_internal_debug() { :; }
        PROMPT_COMMAND="${PROMPT_COMMAND};prompt_internal_debug"
        eval "$PROMPT_COMMAND"
        CHECK_PREVIOUS_TRAP=1
        :
        source "$GENERATED"
        first_title_installer_count=$(grep -o _dotzsh_bash_title_install <<< "$PROMPT_COMMAND" | wc -l)
        trap -p DEBUG
        printf "PREVIOUS_TRAP_RAN=%s\n" "${PREVIOUS_TRAP_RAN:-0}"
        printf "TITLE_INSTALLER_COUNT=%s\n" "$first_title_installer_count"
        printf "PROMPT_COMMAND=%s\n" "$PROMPT_COMMAND"
    ' 2>/dev/null
)"

[[ "$trap_output" == *previous_debug_trap* ]]
[[ "$trap_output" == *PREVIOUS_TRAP_RAN=1* ]]
[[ "$trap_output" == *TITLE_INSTALLER_COUNT=0* ]]
[[ "$trap_output" != *'local installer'* ]]
[[ "$trap_output" != *'prompt_internal_debug:'* ]]
[[ $(grep -o _dotzsh_bash_preexec_debug <<< "$trap_output" | wc -l) -eq 1 ]]
[[ $(grep -o _dotzsh_bash_preexec_arm <<< "$trap_output" | wc -l) -eq 1 ]]

array_prompt_output="$(
    HOME="$tmpdir/home" GENERATED="$generated" bash --noprofile --norc -ic '
        user_prompt() { :; }
        PROMPT_COMMAND=(user_prompt)
        source "$GENERATED"
        declare -p PROMPT_COMMAND
    ' 2>/dev/null
)"

[[ "$array_prompt_output" == *'[0]="_bash_prompt_cmd"'* ]]
[[ "$array_prompt_output" == *'[1]="user_prompt"'* ]]
[[ $(grep -o _bash_prompt_cmd <<< "$array_prompt_output" | wc -l) -eq 1 ]]
[[ $(grep -o _dotzsh_bash_title_install <<< "$array_prompt_output" | wc -l) -eq 1 ]]
[[ $(grep -o _dotzsh_bash_preexec_arm <<< "$array_prompt_output" | wc -l) -eq 1 ]]
