#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
bin_dir="$tmpdir/bin"
gitstatus_dir="$tmpdir/gitstatus"
mkdir -p "$bin_dir" "$gitstatus_dir"
cat > "$bin_dir/flyline" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FLYLINE_CALLS:?}"
exit 0
EOF
chmod +x "$bin_dir/flyline"

cat > "$bin_dir/gitstatus-share" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$gitstatus_dir"
EOF
chmod +x "$bin_dir/gitstatus-share"
cat > "$gitstatus_dir/gitstatus.plugin.sh" <<'EOF'
gitstatus_start() { :; }
gitstatus_query() {
    VCS_STATUS_RESULT=ok-sync
    VCS_STATUS_LOCAL_BRANCH=feature/flyline
    VCS_STATUS_COMMITS_AHEAD=2
    VCS_STATUS_COMMITS_BEHIND=1
    VCS_STATUS_PUSH_COMMITS_AHEAD=0
    VCS_STATUS_PUSH_COMMITS_BEHIND=0
    VCS_STATUS_STASHES=1
    VCS_STATUS_ACTION=
    VCS_STATUS_NUM_CONFLICTED=0
    VCS_STATUS_NUM_STAGED=3
    VCS_STATUS_NUM_UNSTAGED=4
    VCS_STATUS_NUM_UNTRACKED=5
}
EOF

PATH="$bin_dir:$PATH" bash "$repo_root/common.sh.in" stdout > "$generated"

PATH="$bin_dir:$PATH" FLYLINE_CALLS="$tmpdir/flyline.calls" \
    GENERATED="$generated" PLUGIN="$repo_root/plugsfile/flyline.plugin.sh" \
    GITSTATUS_DIR="$gitstatus_dir" \
    bash --noprofile --norc -c '
    set -euo pipefail
    source "$GENERATED"

    shopt -s extdebug
    [[ $(declare -F _dotzsh_bash_prompt_hook) == *"$PLUGIN"* ]]
    [[ $(declare -F _dotzsh_flyline_setup) == *"$PLUGIN"* ]]

    FLYLINE_VERSION=1
    DOTZSH_GITSTATUS_DIR="$GITSTATUS_DIR"
    true
    _bash_prompt_cmd

    [[ $RPS1 == *"FLYLINE_LAST_COMMAND_DURATION\\e[0m "* ]]
    [[ $_dotzsh_bash_prompt_gitstatus == *"feature/flyline"* ]]
    [[ $_dotzsh_bash_prompt_gitstatus == *"⇣1"* && $_dotzsh_bash_prompt_gitstatus == *"⇡2"* ]]
    [[ $_dotzsh_bash_prompt_gitstatus == *"*1"* && $_dotzsh_bash_prompt_gitstatus == *"+3"* && $_dotzsh_bash_prompt_gitstatus == *"!4"* && $_dotzsh_bash_prompt_gitstatus == *"?5"* ]]
    [[ $RPS1 == *\$\{_dotzsh_bash_prompt_gitstatus\}* ]]
    [[ $RPS1 == *"\\e[38;5;245m\\A\\e[0m"* ]]
    [[ $RPS1 != *"FLYLINE_LAST_COMMAND_DURATION\\e[0m\\e[0;245m\\A"* ]]

    grep -Fqx "create-prompt-widget last-command-duration" "$FLYLINE_CALLS"
    grep -Fqx "key bind Ctrl+w always=deleteLeftOneWordPart" "$FLYLINE_CALLS"

    SHLVL=2 DOTZSH_SHLVL_THRESHOLD=1
    true
    _bash_prompt_cmd
    [[ $_dotzsh_bash_prompt_shlvl == "L2" ]]

    DOTZSH_SHLVL_THRESHOLD=2
    true
    _bash_prompt_cmd
    [[ -z $_dotzsh_bash_prompt_shlvl ]]
    '
