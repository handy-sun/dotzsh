#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
bin_dir="$tmpdir/bin"
mkdir -p "$bin_dir"
cat > "$bin_dir/flyline" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin_dir/flyline"

PATH="$bin_dir:$PATH" bash "$repo_root/common.sh.in" stdout > "$generated"

PATH="$bin_dir:$PATH" GENERATED="$generated" PLUGIN="$repo_root/plugsfile/flyline.plugin.sh" \
    bash --noprofile --norc -c '
    set -euo pipefail
    source "$GENERATED"

    shopt -s extdebug
    [[ $(declare -F _dotzsh_bash_prompt_hook) == *"$PLUGIN"* ]]
    [[ $(declare -F _dotzsh_flyline_setup) == *"$PLUGIN"* ]]

    FLYLINE_VERSION=1
    true
    _bash_prompt_cmd

    [[ $RPS1 == *"FLYLINE_LAST_COMMAND_DURATION\\e[0m "* ]]
    [[ $RPS1 != *"FLYLINE_LAST_COMMAND_DURATION\\e[0m\\e[0;245m\\A"* ]]

    SHLVL=2 DOTZSH_SHLVL_THRESHOLD=1
    true
    _bash_prompt_cmd
    [[ $_dotzsh_bash_prompt_shlvl == "L2" ]]

    DOTZSH_SHLVL_THRESHOLD=2
    true
    _bash_prompt_cmd
    [[ -z $_dotzsh_bash_prompt_shlvl ]]
    '
