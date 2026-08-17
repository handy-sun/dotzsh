#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash_bin="$(command -v bash)"
fish_bin="$(command -v fish)"
zsh_bin="$(command -v zsh)"
generated_fish="$tmpdir/common.fish"
history_path_log="$tmpdir/history-path.log"

mkdir -p "$tmpdir/home/.cache" "$tmpdir/data dir/fish"

# Expanded by the child Zsh process, not by this test script.
# shellcheck disable=SC2016
HOME="$tmpdir/home" REPO_ROOT="$repo_root" "$zsh_bin" -d -f -c '
    source "$REPO_ROOT/zsh-config.zsh"
    [[ -o HIST_REDUCE_BLANKS ]]
'

"$bash_bin" "$repo_root/common.fish.in" -0 > "$generated_fish"
touch "$tmpdir/data dir/fish/custom_history"
touch "$tmpdir/data dir/fish/default_history"
touch "$tmpdir/data dir/fish/fish_history"

# Expanded by the child Fish process, not by this test script.
# shellcheck disable=SC2016
run_history_case() {
    local session_name=$1
    local expected_history_path=$2
    local stderr_target=/dev/stderr
    if [[ "$session_name" == */* || "$session_name" == -* ]]; then
        stderr_target="$tmpdir/expected-invalid-session.stderr"
    fi

    HOME="$tmpdir/home" XDG_DATA_HOME="$tmpdir/data dir" \
        GENERATED_FISH="$generated_fish" HISTORY_PATH_LOG="$history_path_log" \
        FISH_HISTORY_SESSION="$session_name" \
        "$fish_bin" --no-config -c '
        source "$GENERATED_FISH"
        set -g fish_history "$FISH_HISTORY_SESSION"

        function grep
            printf "%s\n" "$argv[-1]" > "$HISTORY_PATH_LOG"
        end

        function perl
            return 0
        end

        htdel marker
    ' 2> "$stderr_target"

    local actual_history_path
    actual_history_path="$(<"$history_path_log")"
    if [[ "$actual_history_path" != "$expected_history_path" ]]; then
        printf 'unexpected Fish history path for session <%s>: expected <%s>, got <%s>\n' \
            "$session_name" "$expected_history_path" "$actual_history_path" >&2
        return 1
    fi
}

run_history_case custom "$tmpdir/data dir/fish/custom_history"
run_history_case default "$tmpdir/data dir/fish/default_history"
run_history_case ../escape "$tmpdir/data dir/fish/fish_history"
run_history_case 'foo[/../../../../target' "$tmpdir/data dir/fish/fish_history"
run_history_case --help "$tmpdir/data dir/fish/fish_history"
unicode_session=$'a\u05B0'
touch "$tmpdir/data dir/fish/${unicode_session}_history"
run_history_case "$unicode_session" "$tmpdir/data dir/fish/${unicode_session}_history"

# Expanded by the child Fish process, not by this test script.
# shellcheck disable=SC2016
if HOME="$tmpdir/home" XDG_DATA_HOME="$tmpdir/data dir" \
    GENERATED_FISH="$generated_fish" "$fish_bin" --no-config -c '
        source "$GENERATED_FISH"
        set -g fish_history ""
        htdel marker
    '
then
    printf 'htdel accepted an empty Fish history session\n' >&2
    exit 1
fi

rg -Fq 'echo "launchctl unload "$user_lib_path' "$repo_root/common.fish.in"

if rg -q 'nix shell nixpkgs#|shellcheck .*\|\| true' "$repo_root/.github/workflows/ci.yml"; then
    printf 'CI still uses an unpinned registry package or masks ShellCheck failures\n' >&2
    exit 1
fi
rg -Fq 'nix develop --command shellcheck' "$repo_root/.github/workflows/ci.yml"
rg -Fq 'nix develop --command bash tests/consistency_fixes.sh' "$repo_root/.github/workflows/ci.yml"

for template in common.sh.in common.fish.in; do
    if rg -q 'gitignore\.io' "$repo_root/$template"; then
        printf 'legacy gitignore.io endpoint remains in %s\n' "$template" >&2
        exit 1
    fi
    rg -Fq 'https://www.toptal.com/developers/gitignore/api/' "$repo_root/$template"
done
