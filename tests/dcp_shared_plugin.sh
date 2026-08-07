#!/usr/bin/env bash
## Verify shared docker-compose helpers in Bash and Zsh.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
zsh_bin="$(command -v zsh || true)"
bin_dir="$tmpdir/bin"
generated="$tmpdir/common.sh"
shared_plugin="$repo_root/plugsfile/docker-compose.plugin.sh"
dcp_dir="$tmpdir/dcp dir"

mkdir -p "$bin_dir" "$dcp_dir/svc one" "$dcp_dir/pull" "$dcp_dir/skip"

for command_name in awk bash cat dirname grep ls mkdir mv readlink uname; do
    ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
done
ln -s "$repo_root/tests/fixtures/dcp-command" "$bin_dir/docker-compose"
ln -s "$repo_root/tests/fixtures/dcp-command" "$bin_dir/bat"
ln -s "$repo_root/tests/fixtures/dcp-command" "$bin_dir/editor"

printf '%s\n' 'services:' '  app:' '    restart: always' > "$dcp_dir/svc one/docker-compose.yml"
printf '%s\n' 'services:' '  app:' '    restart: always' > "$dcp_dir/pull/docker-compose.yml"
printf '%s\n' 'services:' '  app:' '    restart: no' > "$dcp_dir/skip/docker-compose.yml"

PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"

assert_count() {
    local expected_count=$1
    local expected_line=$2
    local file=$3
    local context=$4
    local actual_count
    actual_count="$(rg -Fxc "$expected_line" "$file" || true)"
    if [[ "$actual_count" -ne "$expected_count" ]]; then
        printf 'unexpected invocation count for %s: expected %s, got %s\n' \
            "$context" "$expected_count" "$actual_count" >&2
        return 1
    fi
}

run_dcp_checks() {
    local shell_name=$1
    local shell_bin=$2
    local config=$3
    shift 3

    local compose_log="$tmpdir/$shell_name-compose.log"
    local bat_log="$tmpdir/$shell_name-bat.log"
    local editor_log="$tmpdir/$shell_name-editor.log"

    PATH="$bin_dir" \
    DKCP_DIR="$dcp_dir" \
    CONFIG="$config" \
    SHARED_PLUGIN="$shared_plugin" \
    MOCK_BAT_LOG="$bat_log" \
    MOCK_EDITOR_LOG="$editor_log" \
    MOCK_COMMAND_LOG="$compose_log" \
    EDITOR="$bin_dir/editor" \
    "$shell_bin" "$@" -c '
        set -e
        source "$CONFIG"

        for function_name in dcpupd dcpfru dcpdown dcpte dcprs dcppl dcppal dcpca dcped; do
            typeset -f "$function_name" >/dev/null
        done

        if [[ -n ${BASH_VERSION:-} ]]; then
            shopt -s extdebug
            function_origin=$(declare -F dcpupd)
        else
            function_origin=${functions_source[dcpupd]}
        fi
        if [[ $function_origin != *"$SHARED_PLUGIN"* ]]; then
            printf "dcpupd was not loaded from shared plugin: %s\n" "$function_origin" >&2
            exit 1
        fi

        if dcpupd >"$DKCP_DIR/no-arg.out" 2>&1; then
            printf "dcpupd unexpectedly accepted a missing service name\n" >&2
            exit 1
        fi
        grep -Fqx "Usage: dcpupd <service>" "$DKCP_DIR/no-arg.out"

        if dcpupd missing >"$DKCP_DIR/missing.out" 2>&1; then
            printf "dcpupd unexpectedly accepted a missing compose file\n" >&2
            exit 1
        fi
        grep -Fqx "Error: $DKCP_DIR/missing/docker-compose.yml not found" "$DKCP_DIR/missing.out"

        dcpupd "svc one"
        dcpfru "svc one"
        dcpdown "svc one"
        dcpte "svc one"
        dcprs "svc one"
        dcppl "svc one"
        dcppal

        MOCK_COMMAND_LOG="$MOCK_BAT_LOG" dcpca "svc one"
        MOCK_COMMAND_LOG="$MOCK_EDITOR_LOG" dcped "svc one"
    '

    local compose_file="$dcp_dir/svc one/docker-compose.yml"
    local compose_prefix="[-f][$compose_file]"
    assert_count 1 "${compose_prefix}[up][-d]" "$compose_log" "$shell_name dcpupd"
    assert_count 1 "${compose_prefix}[up][-d][--force-recreate][--remove-orphans]" "$compose_log" "$shell_name dcpfru"
    assert_count 1 "${compose_prefix}[down][--remove-orphans]" "$compose_log" "$shell_name dcpdown"
    assert_count 1 "${compose_prefix}[stop]" "$compose_log" "$shell_name dcpte"
    assert_count 1 "${compose_prefix}[restart]" "$compose_log" "$shell_name dcprs"
    assert_count 2 "${compose_prefix}[pull]" "$compose_log" "$shell_name dcppl and dcppal"
    assert_count 1 "[-f][$dcp_dir/pull/docker-compose.yml][pull]" "$compose_log" "$shell_name dcppal normal service"
    assert_count 0 "[-f][$dcp_dir/skip/docker-compose.yml][pull]" "$compose_log" "$shell_name dcppal restart:no service"
    assert_count 1 "[$compose_file]" "$bat_log" "$shell_name dcpca"
    assert_count 1 "[$compose_file]" "$editor_log" "$shell_name dcped"
}

run_dcp_checks bash "$bash_bin" "$generated" --noprofile --norc

if [[ -n "$zsh_bin" ]]; then
    run_dcp_checks zsh "$zsh_bin" "$shared_plugin" -d -f
fi
