#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
jq_bin="$(command -v jq)"
zsh_bin="$(command -v zsh)"

make_bin() {
    local mode=$1
    local bin_dir="$tmpdir/bin-$mode"
    mkdir -p "$bin_dir"

    local command_name
    for command_name in awk bash cat dirname readlink uname; do
        ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
    done
    if [[ "$mode" == jq ]]; then
        ln -s "$jq_bin" "$bin_dir/jq"
    fi

    cat > "$bin_dir/curl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

url=
for arg in "$@"; do
    case "$arg" in
        http://*|https://*) url=$arg ;;
    esac
done
printf '%s\n' "$url" >> "${MOCK_CURL_LOG:?}"

case "$url" in
    https://ipwho.is/*)
        if [[ ${MOCK_IPWHO_FAIL:-0} == 1 ]]; then
            exit 22
        fi
        if [[ ${MOCK_API_FAIL:-0} == 1 ]]; then
            printf '%s\n' '{"success":false,"message":"invalid query"}'
            exit 0
        fi
        printf '%s\n' '{"success":true,"ip":"203.0.113.7","country":"Primary Country","region":"Primary Region","city":"Primary City","latitude":1.25,"longitude":2.5,"connection":{"asn":15169,"org":"Primary Org","isp":"Primary ISP"},"timezone":{"id":"Primary/Zone"},"unused":"hidden"}'
        ;;
    http://ip-api.com/json/*)
        if [[ ${MOCK_IPAPI_FAIL:-0} == 1 ]]; then
            exit 22
        fi
        if [[ ${MOCK_API_FAIL:-0} == 1 ]]; then
            printf '%s\n' '{"status":"fail","message":"invalid query"}'
            exit 0
        fi
        printf '%s\n' '{"status":"success","query":"203.0.113.7","country":"Secondary Country","regionName":"Secondary Region","city":"Secondary City","lat":3.75,"lon":4.5,"timezone":"Secondary/Zone","isp":"Secondary ISP","org":"Secondary Org","as":"AS15169 Secondary Org","unused":"hidden"}'
        ;;
    *)
        printf 'unexpected URL: %s\n' "$url" >&2
        exit 64
        ;;
esac
EOF
    chmod +x "$bin_dir/curl"
    printf '%s\n' "$bin_dir"
}

generate_config() {
    local shell_name=$1
    local mode=$2
    local bin_dir=$3
    local generated="$tmpdir/common-$shell_name-$mode"

    if [[ "$shell_name" == fish ]]; then
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated"
    else
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"
    fi
    printf '%s\n' "$generated"
}

run_qip() {
    local shell_name=$1
    local generated=$2
    local bin_dir=$3
    local query=$4
    local ipwho_fail=${5:-0}
    local ipapi_fail=${6:-0}
    local api_fail=${7:-0}

    if [[ "$shell_name" == fish ]]; then
        PATH="$bin_dir" GENERATED="$generated" QUERY="$query" \
            MOCK_CURL_LOG="$curl_log" MOCK_IPWHO_FAIL="$ipwho_fail" \
            MOCK_IPAPI_FAIL="$ipapi_fail" MOCK_API_FAIL="$api_fail" \
            "$fish_bin" --no-config -c 'source "$GENERATED"; qip "$QUERY"'
    else
        local shell_bin=$bash_bin
        local -a shell_args=(--noprofile --norc)
        if [[ "$shell_name" == zsh ]]; then
            shell_bin=$zsh_bin
            shell_args=(-d -f)
        fi

        PATH="$bin_dir" GENERATED="$generated" QUERY="$query" \
            MOCK_CURL_LOG="$curl_log" MOCK_IPWHO_FAIL="$ipwho_fail" \
            MOCK_IPAPI_FAIL="$ipapi_fail" MOCK_API_FAIL="$api_fail" \
            "$shell_bin" "${shell_args[@]}" -c '
                compdef() { :; }
                source "$GENERATED"
                qip "$QUERY"
            '
    fi
}

assert_contains() {
    local output=$1
    local expected=$2
    local context=$3

    if [[ "$output" != *"$expected"* ]]; then
        printf 'missing %q in qip output for %s\noutput:\n%s\n' \
            "$expected" "$context" "$output" >&2
        return 1
    fi
}

expected_urls=$'https://ipwho.is/203.0.113.7\nhttp://ip-api.com/json/203.0.113.7?fields=status,message,query,country,regionName,city,lat,lon,timezone,isp,org,as'
expected_ipv6_urls=$'https://ipwho.is/2001:db8::1\nhttp://ip-api.com/json/2001:db8::1?fields=status,message,query,country,regionName,city,lat,lon,timezone,isp,org,as'
curl_log="$tmpdir/curl.log"

for mode in jq fallback; do
    bin_dir="$(make_bin "$mode")"
    for shell_name in sh zsh fish; do
        generated="$(generate_config "$shell_name" "$mode" "$bin_dir")"
        : > "$curl_log"

        output="$(run_qip "$shell_name" "$generated" "$bin_dir" 203.0.113.7)"
        context="$shell_name/$mode"
        assert_contains "$output" "=== ipwho.is ===" "$context"
        assert_contains "$output" "Primary City" "$context"
        assert_contains "$output" "=== ip-api.com ===" "$context"
        assert_contains "$output" "Secondary City" "$context"
        if [[ "$mode" == jq && "$(printf '%s\n' "$output" | rg -c '"asn": 15169')" -ne 2 ]]; then
            printf 'qip did not normalize both ASN values for %s\noutput:\n%s\n' \
                "$context" "$output" >&2
            exit 1
        fi
        [[ "$(<"$curl_log")" == "$expected_urls" ]]

        : > "$curl_log"
        output="$(run_qip "$shell_name" "$generated" "$bin_dir" 2001:db8::1)"
        assert_contains "$output" "Primary City" "$context IPv6"
        assert_contains "$output" "Secondary City" "$context IPv6"
        [[ "$(<"$curl_log")" == "$expected_ipv6_urls" ]]

        : > "$curl_log"
        output="$(run_qip "$shell_name" "$generated" "$bin_dir" 203.0.113.7 1 2>&1)"
        assert_contains "$output" "Error: ipwho.is query failed." "$context primary failure"
        assert_contains "$output" "Secondary City" "$context primary failure"
        [[ "$(<"$curl_log")" == "$expected_urls" ]]

        : > "$curl_log"
        output="$(run_qip "$shell_name" "$generated" "$bin_dir" 203.0.113.7 0 1 2>&1)"
        assert_contains "$output" "Primary City" "$context secondary failure"
        assert_contains "$output" "Error: ip-api.com query failed." "$context secondary failure"

        : > "$curl_log"
        if output="$(run_qip "$shell_name" "$generated" "$bin_dir" 203.0.113.7 0 0 1 2>&1)"; then
            printf 'qip treated two API failure responses as success for %s\n' "$context" >&2
            exit 1
        fi
        assert_contains "$output" "Error: ipwho.is returned an invalid response." "$context API failures"
        assert_contains "$output" "Error: ip-api.com returned an invalid response." "$context API failures"

        for invalid_ip in example.com abcd : ::: 1.2.3 01.2.3.4 999.999.999.999 192.0.2.1:: 1:192.0.2.1:: 1::2: ::1:; do
            : > "$curl_log"
            if output="$(run_qip "$shell_name" "$generated" "$bin_dir" "$invalid_ip" 2>&1)"; then
                printf 'qip accepted invalid IP %q for %s\n' "$invalid_ip" "$context" >&2
                exit 1
            fi
            assert_contains "$output" "Usage: qip <IPv4-or-IPv6-address>" "$context invalid input"
            [[ ! -s "$curl_log" ]]
        done
    done
done
