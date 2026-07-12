#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
jq_bin="$(command -v jq)"

make_bin() {
    local mode=$1
    local bin_dir="$tmpdir/bin-$mode"
    mkdir -p "$bin_dir"

    local command_name
    for command_name in awk bash cat column dirname readlink uname; do
        ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
    done
    if [[ "$mode" == jq ]]; then
        ln -s "$jq_bin" "$bin_dir/jq"
    fi

    cp "$repo_root/tests/fixtures/rlip6-ip" "$bin_dir/ip"
    chmod +x "$bin_dir/ip"
    printf '%s\n' "$bin_dir"
}

generate_config() {
    local shell_name=$1
    local mode=$2
    local bin_dir=$3
    local generated="$tmpdir/common-$shell_name-$mode"

    if [[ "$shell_name" == sh ]]; then
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"
    else
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated"
    fi
    printf '%s\n' "$generated"
}

run_rlip6() {
    local shell_name=$1
    local generated=$2
    local bin_dir=$3
    local route_mode=$4

    if [[ "$shell_name" == sh ]]; then
        # Expanded by the child Bash process, not by this test script.
        # shellcheck disable=SC2016
        PATH="$bin_dir" MOCK_ROUTE_MODE="$route_mode" GENERATED="$generated" \
            "$bash_bin" --noprofile --norc -c 'source "$GENERATED"; rlip6'
    else
        # Expanded by the child fish process, not by this test script.
        # shellcheck disable=SC2016
        PATH="$bin_dir" MOCK_ROUTE_MODE="$route_mode" GENERATED="$generated" \
            "$fish_bin" --no-config -c 'source "$GENERATED"; rlip6'
    fi
}

normalize() {
    awk '{$1=$1; print}'
}

assert_output() {
    local expected=$1
    local actual=$2
    local context=$3

    if [[ "$actual" != "$expected" ]]; then
        printf 'unexpected rlip6 output for %s\nexpected:\n%s\nactual:\n%s\n' \
            "$context" "$expected" "$actual" >&2
        return 1
    fi
}

jq_bin_dir="$(make_bin jq)"
fallback_bin_dir="$(make_bin fallback)"

expected_routed=$'2001:db8:1::abcd 64 enp4s0\nfd00:144::9 64 zt6\nfd66::2 64 corp0\nfd77::2 128 vpn42\nfd7a:115c:a1e0::2 128 tailscale0'
expected_vpn_only=$'fd00:144::9 64 zt6\nfd66::2 64 corp0\nfd77::2 128 vpn42\nfd7a:115c:a1e0::2 128 tailscale0'

for mode in jq fallback; do
    for shell_name in sh fish; do
        if [[ "$mode" == jq ]]; then
            bin_dir=$jq_bin_dir
        else
            bin_dir=$fallback_bin_dir
        fi
        generated="$(generate_config "$shell_name" "$mode" "$bin_dir")"

        actual="$(run_rlip6 "$shell_name" "$generated" "$bin_dir" success | normalize)"
        assert_output "$expected_routed" "$actual" "$shell_name/$mode route success"

        actual="$(run_rlip6 "$shell_name" "$generated" "$bin_dir" failure | normalize)"
        assert_output "$expected_vpn_only" "$actual" "$shell_name/$mode route failure"
    done
done
