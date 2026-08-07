#!/usr/bin/env bash
## Verify portable plugsfile behavior in Bash and Zsh.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
zsh_bin="$(command -v zsh)"
bin_dir="$tmpdir/bin"
mkdir -p "$bin_dir"
ln -s "$repo_root/tests/fixtures/man-command" "$bin_dir/man"
ln -s "$(type -P true)" "$bin_dir/less"
ln -s "$repo_root/tests/fixtures/command-failure" "$bin_dir/realpath"

run_in_shells() {
    local callback=$1
    "$callback" bash "$bash_bin" --noprofile --norc
    "$callback" zsh "$zsh_bin" -d -f
}

test_copypath_shell() {
    local shell_name=$1
    local shell_bin=$2
    shift 2

    local plugin="$repo_root/plugsfile/copypath.plugin.sh"
    local copy_log="$tmpdir/$shell_name-copypath.log"
    local work_dir="$tmpdir/$shell_name work"
    mkdir -p "$work_dir"

    PATH="$bin_dir:$PATH" \
    PLUGIN="$plugin" COPY_LOG="$copy_log" WORK_DIR="$work_dir" \
    "$shell_bin" "$@" -c '
        set -e
        getcopycmd() { printf "cat > %s\n" "$COPY_LOG"; }
        source "$PLUGIN"

        if [[ -n ${BASH_VERSION:-} ]]; then
            shopt -s extdebug
            function_origin=$(declare -F copypath)
        else
            function_origin=${functions_source[copypath]}
        fi
        [[ $function_origin == *"$PLUGIN"* ]]

        cd "$WORK_DIR"
        output=$(copypath "relative dir/file name")
        [[ $(cat "$COPY_LOG") == "$WORK_DIR/relative dir/file name" ]]
        [[ $output == *"copied to clipboard."* ]]

        copypath >/dev/null
        [[ $(cat "$COPY_LOG") == "$WORK_DIR" ]]
    '
}

test_copybuffer_shell() {
    local shell_name=$1
    local shell_bin=$2
    shift 2

    local plugin="$repo_root/plugsfile/copybuffer.plugin.sh"
    local copy_log="$tmpdir/$shell_name-copybuffer.log"

    PATH="$bin_dir:$PATH" \
    PLUGIN="$plugin" COPY_LOG="$copy_log" \
    "$shell_bin" "$@" -c '
        set -e
        getcopycmd() { printf "cat > %s\n" "$COPY_LOG"; }
        source "$PLUGIN"

        if [[ -n ${BASH_VERSION:-} ]]; then
            shopt -s extdebug
            function_origin=$(declare -F copybuffer)
            READLINE_LINE="echo shared buffer"
        else
            function_origin=${functions_source[copybuffer]}
            BUFFER="echo shared buffer"
        fi
        [[ $function_origin == *"$PLUGIN"* ]]

        copybuffer
        [[ $(cat "$COPY_LOG") == "echo shared buffer" ]]
    '
}

test_copybuffer_bindings() {
    local plugin="$repo_root/plugsfile/copybuffer.plugin.sh"
    local binding_output

    binding_output="$(PLUGIN="$plugin" "$bash_bin" --noprofile --norc -ic 'source "$PLUGIN"; bind -X' 2>/dev/null)"
    grep -Fqx '"\C-o" "copybuffer"' <<< "$binding_output"

    for keymap in emacs viins vicmd; do
        binding_output="$(PLUGIN="$plugin" KEYMAP="$keymap" "$zsh_bin" -d -f -c 'source "$PLUGIN"; bindkey -M "$KEYMAP" "^O"')"
        grep -Fqx '"^O" copybuffer' <<< "$binding_output"
    done
}

test_colored_man_shell() {
    local shell_name=$1
    local shell_bin=$2
    shift 2

    local plugin="$repo_root/plugsfile/colored-man-pages.plugin.sh"
    local man_log="$tmpdir/$shell_name-man.log"

    PATH="$bin_dir:$PATH" \
    PLUGIN="$plugin" MOCK_MAN_LOG="$man_log" \
    "$shell_bin" "$@" -c '
        set -e
        source "$PLUGIN"
        for function_name in colored man dman debman; do
            typeset -f "$function_name" >/dev/null
        done

        if [[ -n ${BASH_VERSION:-} ]]; then
            shopt -s extdebug
            function_origin=$(declare -F man)
        else
            function_origin=${functions_source[man]}
        fi
        [[ $function_origin == *"$PLUGIN"* ]]

        man "topic name"
    '

    grep -Fqx "PAGER=[$bin_dir/less]" "$man_log"
    grep -Fqx 'GROFF_NO_SGR=[1]' "$man_log"
    grep -Fqx 'ARG=[topic name]' "$man_log"
    for variable_name in mb md me so se us ue; do
        if grep -Fqx "LESS_TERMCAP_$variable_name=[]" "$man_log"; then
            printf 'empty LESS_TERMCAP_%s for %s\n' "$variable_name" "$shell_name" >&2
            return 1
        fi
    done
}

case ${1:-all} in
    copypath)
        run_in_shells test_copypath_shell
        ;;
    copybuffer)
        run_in_shells test_copybuffer_shell
        test_copybuffer_bindings
        ;;
    colored-man)
        run_in_shells test_colored_man_shell
        ;;
    all)
        run_in_shells test_copypath_shell
        run_in_shells test_copybuffer_shell
        test_copybuffer_bindings
        run_in_shells test_colored_man_shell
        ;;
    *)
        printf 'Usage: %s [copypath|copybuffer|colored-man|all]\n' "$0" >&2
        exit 2
        ;;
esac
