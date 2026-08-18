#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.fish"
bash "$repo_root/common.fish.in" -0p > "$generated"

result="$(
    HOME="$tmpdir/home" GENERATED="$generated" \
        fish --no-config -i -c '
        source "$GENERATED"
        function set_color
            if test "$argv[1]" = -o
                printf "<bold:%s>" "$argv[2]"
            else
                printf "<%s>" "$argv[1]"
            end
        end
        function prompt_login; printf ctx; end
        function date; printf 12:34:56; end
        function jobs; return 0; end

        set -l level $SHLVL
        set -gx DOTZSH_SHLVL_THRESHOLD (math $level - 1)
        set -l shown (fish_right_prompt)
        set -gx DOTZSH_SHLVL_THRESHOLD $level
        set -l hidden (fish_right_prompt)
        printf "%s|%s|%s\\n" "$level" "$shown" "$hidden"
        ' 2>/dev/null
)"

level="${result%%|*}"
rest="${result#*|}"
shown="${rest%%|*}"
hidden="${rest#*|}"

[[ $level =~ ^[0-9]+$ ]]
[[ $shown == *" L$level"* ]]
[[ $hidden != *" L$level"* ]]
