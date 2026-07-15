#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
zsh_bin="$(command -v zsh)"

mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/tput" << 'EOF'
#!/usr/bin/env bash
if [[ ${1:-} != lines || ${MOCK_TPUT_MODE:-success} == failure ]]; then
    exit 1
fi
printf '%s\n' "${MOCK_TERMINAL_LINES:?}"
if [[ ${MOCK_TPUT_MODE:-success} == failure-with-output ]]; then
    exit 1
fi
EOF
chmod +x "$tmpdir/bin/tput"

generate_config() {
    local shell_name=$1
    local generated="$tmpdir/common-$shell_name"

    if [[ "$shell_name" == fish ]]; then
        "$bash_bin" "$repo_root/common.fish.in" -0 > "$generated"
    else
        "$bash_bin" "$repo_root/common.sh.in" stdout > "$generated"
    fi
    printf '%s\n' "$generated"
}

run_glh() {
    local shell_name=$1
    local generated=$2
    local terminal_lines=$3
    local tput_mode=$4

    if [[ "$shell_name" != fish ]]; then
        local shell_bin=$bash_bin
        local -a shell_args=(--noprofile --norc)
        if [[ "$shell_name" == zsh ]]; then
            shell_bin=$zsh_bin
            shell_args=(-d -f)
        fi

        # Expanded by the child shell process, not by this test script.
        # shellcheck disable=SC2016
        PATH="$tmpdir/bin:$PATH" GENERATED="$generated" \
            MOCK_TERMINAL_LINES="$terminal_lines" MOCK_TPUT_MODE="$tput_mode" \
            "$shell_bin" "${shell_args[@]}" -c '
                compdef() { :; }
                source "$GENERATED"
                unalias glp 2>/dev/null || true
                glp() {
                    [[ ${1:-} == --color=always ]] || return 64
                    local i
                    for ((i = 1; i <= 50; i++)); do
                        printf "\033[31mline-%02d\033[0m\n" "$i"
                    done
                }
                set -e
                glh
            '
    else
        # Expanded by the child fish process, not by this test script.
        # shellcheck disable=SC2016
        PATH="$tmpdir/bin:$PATH" GENERATED="$generated" \
            MOCK_TERMINAL_LINES="$terminal_lines" MOCK_TPUT_MODE="$tput_mode" \
            "$fish_bin" --no-config -c '
                source "$GENERATED"
                functions --erase glp
                function glp
                    test "$argv[1]" = --color=always; or return 64
                    for i in (seq 50)
                        printf "\033[31mline-%02d\033[0m\n" "$i"
                    end
                end
                glh
            '
    fi
}

assert_glh() {
    local expected_lines=$1
    local actual=$2
    local context=$3
    local actual_lines

    actual_lines="$(printf '%s' "$actual" | awk 'END { print NR }')"
    if [[ "$actual_lines" -ne "$expected_lines" ]]; then
        printf 'unexpected glh line count for %s: expected %d, got %d\n' \
            "$context" "$expected_lines" "$actual_lines" >&2
        return 1
    fi

    if [[ "$expected_lines" -gt 0 && "$actual" != *$'\033[31m'* ]]; then
        printf 'glh output lost ANSI colors for %s\n' "$context" >&2
        return 1
    fi
}

for shell_name in sh zsh fish; do
    generated="$(generate_config "$shell_name")"

    actual="$(run_glh "$shell_name" "$generated" 10 success)"
    assert_glh 8 "$actual" "$shell_name 10-line terminal"

    for tiny_height in 0 1 2; do
        actual="$(run_glh "$shell_name" "$generated" "$tiny_height" success)"
        assert_glh 0 "$actual" "$shell_name $tiny_height-line terminal"
    done

    actual="$(run_glh "$shell_name" "$generated" 40 success)"
    assert_glh 30 "$actual" "$shell_name 40-line terminal"

    actual="$(run_glh "$shell_name" "$generated" 0 failure)"
    assert_glh 30 "$actual" "$shell_name tput fallback"

    actual="$(run_glh "$shell_name" "$generated" 10 failure-with-output)"
    assert_glh 30 "$actual" "$shell_name tput numeric failure fallback"
done
