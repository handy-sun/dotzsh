#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
zsh_bin="$(command -v zsh)"
sudo_log="$tmpdir/sudo.log"

make_bin() {
    local platform=$1
    local bin_dir="$tmpdir/bin-$platform"
    mkdir -p "$bin_dir"

    local command_name
    for command_name in awk bash cat dirname id readlink; do
        ln -s "$(command -v "$command_name")" "$bin_dir/$command_name"
    done
    if [[ "$platform" == darwin ]]; then
        cp "$repo_root/tests/fixtures/uname-darwin" "$bin_dir/uname"
        cp "$repo_root/tests/fixtures/lanscan-route" "$bin_dir/route"
        cp "$repo_root/tests/fixtures/lanscan-ifconfig" "$bin_dir/ifconfig"
    else
        ln -s "$(command -v uname)" "$bin_dir/uname"
        cp "$repo_root/tests/fixtures/lanscan-ip" "$bin_dir/ip"
    fi
    cp "$repo_root/tests/fixtures/lanscan-nmap" "$bin_dir/nmap"
    cp "$repo_root/tests/fixtures/lanscan-sudo" "$bin_dir/sudo"
    chmod +x "$bin_dir/nmap" "$bin_dir/sudo"
    if [[ "$platform" == darwin ]]; then
        chmod +x "$bin_dir/route" "$bin_dir/ifconfig"
    else
        chmod +x "$bin_dir/ip"
    fi
    printf '%s\n' "$bin_dir"
}

generate_config() {
    local shell_name=$1 bin_dir=$2
    local generated
    generated="$tmpdir/common-$shell_name-$(basename "$bin_dir")"

    if [[ "$shell_name" == fish ]]; then
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated"
    else
        PATH="$bin_dir" "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"
    fi
    printf '%s\n' "$generated"
}

run_lanscan() {
    local shell_name=$1 generated=$2 bin_dir=$3 arg=$4
    local -a env=(PATH="$bin_dir" GENERATED="$generated" LANSCAN_ARG="$arg"
        MOCK_SUDO_LOG="$sudo_log" MOCK_IP_MODE="${MOCK_IP_MODE:-default}")

    if [[ "$shell_name" == fish ]]; then
        env "${env[@]}" "$fish_bin" --no-config -c '
            source "$GENERATED"
            if test -n "$LANSCAN_ARG"
                lanscan $LANSCAN_ARG
            else
                lanscan
            end
        '
    else
        local shell_bin=$bash_bin
        local -a shell_args=(--noprofile --norc)
        if [[ "$shell_name" == zsh ]]; then
            shell_bin=$zsh_bin
            shell_args=(-d -f)
        fi
        env "${env[@]}" "$shell_bin" "${shell_args[@]}" -c '
            compdef() { :; }
            source "$GENERATED"
            lanscan $LANSCAN_ARG
        '
    fi
}

assert_contains() {
    local output=$1 expected=$2 context=$3
    [[ "$output" == *"$expected"* ]] || {
        printf 'missing %q in lanscan output for %s\noutput:\n%s\n' \
            "$expected" "$context" "$output" >&2
        return 1
    }
}

# widths are content-fitted: longest ip (192.168.1.105 = 13), hostname capped
# at 12 (a-very-long-hostname.example -> a-very-lo...), longest mac (17)
expected_table=""
expected_row() {
    local line
    printf -v line '%-13s  %-12s  %-17s  %s' "$1" "$2" "$3" "$4"
    line="${line%"${line##*[! ]}"}"  # trim trailing padding when vendor is empty
    expected_table+="$line"$'\n'
}
expected_row '192.168.1.1' 'router.lan' 'AA:BB:CC:DD:EE:FF' 'Tp-Link Technologies Co.,Ltd.'
expected_row '192.168.1.7' 'a-very-lo...' '22:22:22:22:22:22' 'Espressif Inc.'
expected_row '192.168.1.23' '-' '-' ''
expected_row '192.168.1.105' '-' '11:22:33:44:55:66' 'Apple, Inc.'
expected_row '192.168.1.200' 'nas' '99:88:77:66:55:44' 'Synology Incorporated'
expected_table+="# 5 hosts up in 192.168.1.0/24"

for platform in linux darwin; do
    bin_dir="$(make_bin "$platform")"
    for shell_name in sh zsh fish; do
        generated="$(generate_config "$shell_name" "$bin_dir")"
        context="$shell_name/$platform"
        : > "$sudo_log"

        output="$(run_lanscan "$shell_name" "$generated" "$bin_dir" '192.168.1.0/24' 2>&1)"
        assert_contains "$output" "$expected_table" "$context table"
        assert_contains "$output" '# lanscan: sudo nmap -sn 192.168.1.0/24' "$context header"
        [[ "$(<"$sudo_log")" == 'sudo nmap -sn 192.168.1.0/24' ]] || {
            printf 'unexpected sudo invocation log for %s:\n%s\n' \
                "$context" "$(<"$sudo_log")" >&2
            exit 1
        }
    done

    # auto-detected subnet (no explicit CIDR)
    : > "$sudo_log"
    generated_sh="$(generate_config sh "$bin_dir")"
    if [[ "$platform" == linux ]]; then
        detected_cidr='192.168.168.0/22'
    else
        detected_cidr='10.0.0.32/27'
    fi
    output="$(run_lanscan sh "$generated_sh" "$bin_dir" '' 2>&1)"
    assert_contains "$output" "# lanscan: sudo nmap -sn $detected_cidr" "$platform auto-detect"

    # detection failure must fail with guidance and never reach sudo (linux only:
    # the darwin stubs for route/ifconfig have no failure mode)
    if [[ "$platform" == linux ]]; then
        : > "$sudo_log"
        if MOCK_IP_MODE=empty output="$(run_lanscan sh "$generated_sh" "$bin_dir" '' 2>&1)"; then
            printf 'lanscan succeeded although subnet detection failed (%s)\n' "$platform" >&2
            exit 1
        fi
        assert_contains "$output" 'cannot detect the local subnet' "$platform no-subnet"
        [[ ! -s "$sudo_log" ]]
    fi
done

printf 'lanscan tests passed\n'
