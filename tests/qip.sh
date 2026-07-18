#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
jq_bin="$(command -v jq)"
zsh_bin="$(command -v zsh)"
curl_log="$tmpdir/curl.log"

make_bin() {
    local mode=$1
    local bin_dir="$tmpdir/bin-$mode"
    mkdir -p "$bin_dir"

    local command_name
    for command_name in awk bash cat dirname readlink uname; do
        ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
    done
    [[ "$mode" == jq ]] && ln -s "$jq_bin" "$bin_dir/jq"

    cat > "$bin_dir/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

url=${!#}
printf '%s\n' "$url" >> "${MOCK_CURL_LOG:?}"
case "$url" in
    https://ipwho.is/*)
        [[ ${MOCK_FAIL:-} == ipwho || ${MOCK_FAIL:-} == both ]] && exit 22
        printf '%s\n' '{"source":"ipwho","city":"Primary City","unused":"primary extra"}'
        ;;
    http://ip-api.com/json/*)
        [[ ${MOCK_FAIL:-} == ip-api || ${MOCK_FAIL:-} == both ]] && exit 22
        printf '%s\n' '{"source":"ip-api","city":"Secondary City","unused":"secondary extra"}'
        ;;
    *) exit 64 ;;
esac
EOF
    chmod +x "$bin_dir/curl"
    printf '%s\n' "$bin_dir"
}

generate_config() {
    local shell_name=$1 mode=$2 bin_dir=$3
    local generated="$tmpdir/common-$shell_name-$mode"

    if [[ "$shell_name" == fish ]]; then
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated"
    else
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"
    fi
    printf '%s\n' "$generated"
}

run_qip() {
    local shell_name=$1 generated=$2 bin_dir=$3 arg_mode=$4
    local fail_source=${5:-}

    if [[ "$shell_name" == fish ]]; then
        PATH="$bin_dir" GENERATED="$generated" ARG_MODE="$arg_mode" \
            MOCK_CURL_LOG="$curl_log" MOCK_FAIL="$fail_source" \
            "$fish_bin" --no-config -c '
                source "$GENERATED"
                switch "$ARG_MODE"
                    case one; qip 203.0.113.7
                    case none; qip
                    case many; qip 203.0.113.7 2001:db8::1
                end
            '
    else
        local shell_bin=$bash_bin
        local -a shell_args=(--noprofile --norc)
        if [[ "$shell_name" == zsh ]]; then
            shell_bin=$zsh_bin
            shell_args=(-d -f)
        fi
        PATH="$bin_dir" GENERATED="$generated" ARG_MODE="$arg_mode" \
            MOCK_CURL_LOG="$curl_log" MOCK_FAIL="$fail_source" \
            "$shell_bin" "${shell_args[@]}" -c '
                compdef() { :; }
                source "$GENERATED"
                case "$ARG_MODE" in
                    one) qip 203.0.113.7 ;;
                    none) qip ;;
                    many) qip 203.0.113.7 2001:db8::1 ;;
                esac
            '
    fi
}

assert_contains() {
    local output=$1 expected=$2 context=$3
    [[ "$output" == *"$expected"* ]] || {
        printf 'missing %q in qip output for %s\noutput:\n%s\n' \
            "$expected" "$context" "$output" >&2
        return 1
    }
}

expected_urls=$'https://ipwho.is/203.0.113.7\nhttp://ip-api.com/json/203.0.113.7'

for mode in jq fallback; do
    bin_dir="$(make_bin "$mode")"
    for shell_name in sh zsh fish; do
        generated="$(generate_config "$shell_name" "$mode" "$bin_dir")"
        context="$shell_name/$mode"
        : > "$curl_log"

        output="$(run_qip "$shell_name" "$generated" "$bin_dir" one)"
        assert_contains "$output" "=== ipwho.is ===" "$context"
        assert_contains "$output" "primary extra" "$context"
        assert_contains "$output" "=== ip-api.com ===" "$context"
        assert_contains "$output" "secondary extra" "$context"
        [[ "$(<"$curl_log")" == "$expected_urls" ]]

        output="$(run_qip "$shell_name" "$generated" "$bin_dir" one ipwho 2>&1)"
        assert_contains "$output" "Error: ipwho.is query failed." "$context primary failure"
        assert_contains "$output" "Secondary City" "$context primary failure"

        if output="$(run_qip "$shell_name" "$generated" "$bin_dir" one both 2>&1)"; then
            printf 'qip succeeded when both sources failed for %s\n' "$context" >&2
            exit 1
        fi

        for arg_mode in none many; do
            : > "$curl_log"
            if output="$(run_qip "$shell_name" "$generated" "$bin_dir" "$arg_mode" 2>&1)"; then
                printf 'qip accepted %s arguments for %s\n' "$arg_mode" "$context" >&2
                exit 1
            fi
            assert_contains "$output" "Usage: qip <IP-address>" "$context $arg_mode"
            [[ ! -s "$curl_log" ]]
        done
    done
done
