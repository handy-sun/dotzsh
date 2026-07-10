# `rlip4` Route and VPN Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `rlip4` print the IPv4 selected for traffic to `223.5.5.5` plus every ZeroTier, Tailscale, WireGuard, TUN, TAP, or PPP IPv4 address.

**Architecture:** Keep `rlip4` self-contained in each generated shell. Combine the route-selected source with VPN interfaces detected from both kernel link metadata and well-known name prefixes, deduplicate by IPv4, and retain the existing address/prefix/interface output. Exercise the generated Bash/zsh and fish implementations through a deterministic fake `ip` command in both `jq` and jq-free environments.

**Tech Stack:** Bash, fish, iproute2 output formats, jq, awk, column

---

## File Map

- Create `tests/rlip4.sh`: integration test that generates and executes all four `rlip4` variants against controlled route, link, and address data.
- Create `tests/fixtures/rlip4-ip`: deterministic fake iproute2 output for the integration test.
- Modify `common.sh.in`: implement route plus VPN selection for the jq and Linux jq-free Bash/zsh branches.
- Modify `common.fish.in`: mirror the same behavior in the jq and Linux jq-free fish branches.

### Task 1: Add the generated-shell regression matrix

**Files:**
- Create: `tests/rlip4.sh`
- Create: `tests/fixtures/rlip4-ip`
- Test: `tests/rlip4.sh`

- [ ] **Step 1: Write the failing integration test**

Create `tests/rlip4.sh` with this content:

```bash
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

    cp "$repo_root/tests/fixtures/rlip4-ip" "$bin_dir/ip"
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

run_rlip4() {
    local shell_name=$1
    local generated=$2
    local bin_dir=$3
    local route_mode=$4

    if [[ "$shell_name" == sh ]]; then
        PATH="$bin_dir" MOCK_ROUTE_MODE="$route_mode" GENERATED="$generated" \
            "$bash_bin" --noprofile --norc -c 'source "$GENERATED"; rlip4'
    else
        PATH="$bin_dir" MOCK_ROUTE_MODE="$route_mode" GENERATED="$generated" \
            "$fish_bin" --no-config -c 'source "$GENERATED"; rlip4'
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
        printf 'unexpected rlip4 output for %s\nexpected:\n%s\nactual:\n%s\n' \
            "$context" "$expected" "$actual" >&2
        return 1
    fi
}

jq_bin_dir="$(make_bin jq)"
fallback_bin_dir="$(make_bin fallback)"

expected_routed=$'192.168.1.29 24 enp4s0\n10.144.2.9 16 ztmosdpe46\n10.66.0.2 24 corp0\n100.64.0.2 32 tailscale0'
expected_vpn_only=$'10.144.2.9 16 ztmosdpe46\n10.66.0.2 24 corp0\n100.64.0.2 32 tailscale0'

for shell_name in sh fish; do
    for mode in jq fallback; do
        if [[ "$mode" == jq ]]; then
            bin_dir=$jq_bin_dir
        else
            bin_dir=$fallback_bin_dir
        fi
        generated="$(generate_config "$shell_name" "$mode" "$bin_dir")"

        actual="$(run_rlip4 "$shell_name" "$generated" "$bin_dir" success | normalize)"
        assert_output "$expected_routed" "$actual" "$shell_name/$mode route success"

        actual="$(run_rlip4 "$shell_name" "$generated" "$bin_dir" failure | normalize)"
        assert_output "$expected_vpn_only" "$actual" "$shell_name/$mode route failure"
    done
done
```

Create `tests/fixtures/rlip4-ip` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

route_mode=${MOCK_ROUTE_MODE:-success}

case "$*" in
    '-j route get 223.5.5.5')
        [[ "$route_mode" == success ]] || exit 2
        printf '%s\n' '[{"dst":"223.5.5.5","gateway":"192.168.1.1","dev":"enp4s0","prefsrc":"192.168.1.29"}]'
        ;;
    '-j -d addr')
        printf '%s\n' '[
          {"ifname":"lo","link_type":"loopback","addr_info":[{"family":"inet","local":"127.0.0.1","prefixlen":8,"label":"lo"}]},
          {"ifname":"enp4s0","link_type":"ether","addr_info":[{"family":"inet","local":"192.168.1.29","prefixlen":24,"label":"enp4s0"}]},
          {"ifname":"enp5s0","link_type":"ether","addr_info":[{"family":"inet","local":"192.168.50.2","prefixlen":24,"label":"enp5s0"}]},
          {"ifname":"ztmosdpe46","link_type":"ether","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"10.144.2.9","prefixlen":16,"label":"ztmosdpe46"}]},
          {"ifname":"corp0","link_type":"none","linkinfo":{"info_kind":"wireguard"},"addr_info":[{"family":"inet","local":"10.66.0.2","prefixlen":24,"label":"corp0"}]},
          {"ifname":"tailscale0","link_type":"none","addr_info":[{"family":"inet","local":"100.64.0.2","prefixlen":32,"label":"tailscale0"}]},
          {"ifname":"docker0","link_type":"ether","linkinfo":{"info_kind":"bridge"},"addr_info":[{"family":"inet","local":"172.17.0.1","prefixlen":16,"label":"docker0"}]}
        ]'
        ;;
    '-4 route get 223.5.5.5')
        [[ "$route_mode" == success ]] || exit 2
        printf '%s\n' '223.5.5.5 via 192.168.1.1 dev enp4s0 src 192.168.1.29 uid 1000'
        ;;
    '-o link show type tun')
        printf '%s\n' '4: ztmosdpe46: <BROADCAST,UP,LOWER_UP> mtu 2800'
        ;;
    '-o link show type wireguard')
        printf '%s\n' '5: corp0: <POINTOPOINT,UP,LOWER_UP> mtu 1420'
        ;;
    '-o link show type ppp')
        ;;
    '-o -4 addr list')
        printf '%s\n' \
            '1: lo inet 127.0.0.1/8 scope host lo' \
            '2: enp4s0 inet 192.168.1.29/24 scope global enp4s0' \
            '3: enp5s0 inet 192.168.50.2/24 scope global enp5s0' \
            '4: ztmosdpe46 inet 10.144.2.9/16 scope global ztmosdpe46' \
            '5: corp0 inet 10.66.0.2/24 scope global corp0' \
            '6: tailscale0 inet 100.64.0.2/32 scope global tailscale0' \
            '7: docker0 inet 172.17.0.1/16 scope global docker0'
        ;;
    *)
        printf 'unexpected mock ip arguments: %s\n' "$*" >&2
        exit 64
        ;;
esac
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
bash tests/rlip4.sh
```

Expected: FAIL in the first `sh/jq route success` case because the current implementation prints unrelated physical addresses and omits VPN metadata selection.

### Task 2: Implement route and VPN selection in jq branches

**Files:**
- Modify: `common.sh.in:671-673`
- Modify: `common.fish.in:687-689`
- Test: `tests/rlip4.sh`

- [ ] **Step 1: Replace the Bash/zsh jq implementation**

Use this function body in `common.sh.in`:

```bash
rlip4() {
    local route_ip
    route_ip=$(ip -j route get 223.5.5.5 2>/dev/null | jq -r '.[0] | .prefsrc // .src // empty' 2>/dev/null)
    ip -j -d addr | jq -r --arg route_ip "$route_ip" '
        [
            .[]
            | .ifname as $name
            | (.linkinfo.info_kind // "") as $kind
            | (
                ($kind | test("^(tun|tap|wireguard|ppp)$"; "i"))
                or ($name | test("^(zt|tailscale|wg|tun|tap|ppp)"; "i"))
              ) as $is_vpn
            | .addr_info[]?
            | select(.family == "inet" and (.local == $route_ip or $is_vpn))
            | { local, prefixlen, label: (.label // $name) }
        ]
        | unique_by(.local)
        | sort_by(if .local == $route_ip then 0 else 1 end)
        | .[]
        | "\(.local) \(.prefixlen) \(.label)"
    ' | column -t
}
```

- [ ] **Step 2: Mirror the jq implementation in fish**

Use this function body in `common.fish.in`:

```fish
function rlip4 -d "List routed and VPN IPv4 addresses"
    set -l route_ip (ip -j route get 223.5.5.5 2>/dev/null | jq -r '.[0] | .prefsrc // .src // empty' 2>/dev/null)
    ip -j -d addr | jq -r --arg route_ip "$route_ip" '
        [
            .[]
            | .ifname as $name
            | (.linkinfo.info_kind // "") as $kind
            | (
                ($kind | test("^(tun|tap|wireguard|ppp)$"; "i"))
                or ($name | test("^(zt|tailscale|wg|tun|tap|ppp)"; "i"))
              ) as $is_vpn
            | .addr_info[]?
            | select(.family == "inet" and (.local == $route_ip or $is_vpn))
            | { local, prefixlen, label: (.label // $name) }
        ]
        | unique_by(.local)
        | sort_by(if .local == $route_ip then 0 else 1 end)
        | .[]
        | "\(.local) \(.prefixlen) \(.label)"
    ' | column -t
end
```

- [ ] **Step 3: Run the test matrix**

Run `bash tests/rlip4.sh`.

Expected: jq cases now produce the specified rows; jq-free cases still fail because they use the old blacklist.

### Task 3: Implement the jq-free route and VPN selection

**Files:**
- Modify: `common.sh.in:693-695`
- Modify: `common.fish.in:709-711`
- Test: `tests/rlip4.sh`

- [ ] **Step 1: Replace the Bash/zsh jq-free implementation**

Use this function body in `common.sh.in`:

```bash
rlip4() {
    local route_ip vpn_interfaces
    route_ip=$(ip -4 route get 223.5.5.5 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')
    vpn_interfaces=$(
        for kind in tun wireguard ppp; do
            ip -o link show type "$kind" 2>/dev/null
        done | awk -F': ' '{ sub(/@.*/, "", $2); print $2 }'
    )
    ip -o -4 addr list | awk -v route_ip="$route_ip" -v vpn_interfaces="$vpn_interfaces" '
        BEGIN {
            count = split(vpn_interfaces, interfaces, "\n")
            for (i = 1; i <= count; i++) is_vpn[interfaces[i]] = 1
        }
        {
            interface = $2
            sub(/@.*/, "", interface)
            split($4, cidr, "/")
            ip_address = cidr[1]
            if (ip_address == route_ip || is_vpn[interface] || tolower(interface) ~ /^(zt|tailscale|wg|tun|tap|ppp)/) {
                if (!(ip_address in selected)) {
                    order[++selected_count] = ip_address
                    selected[ip_address] = ip_address " " cidr[2] " " interface
                }
            }
        }
        END {
            if (route_ip in selected) print selected[route_ip]
            for (i = 1; i <= selected_count; i++)
                if (order[i] != route_ip) print selected[order[i]]
        }
    ' | column -t
}
```

- [ ] **Step 2: Mirror the jq-free implementation in fish**

Use this function body in `common.fish.in`:

```fish
function rlip4 -d "List routed and VPN IPv4 addresses"
    set -l route_ip (ip -4 route get 223.5.5.5 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')
    set -l vpn_interfaces (
        for kind in tun wireguard ppp
            ip -o link show type "$kind" 2>/dev/null
        end | awk -F': ' '{ sub(/@.*/, "", $2); print $2 }'
    )
    ip -o -4 addr list | awk -v route_ip="$route_ip" -v vpn_interfaces="$(string join \n $vpn_interfaces)" '
        BEGIN {
            count = split(vpn_interfaces, interfaces, "\n")
            for (i = 1; i <= count; i++) is_vpn[interfaces[i]] = 1
        }
        {
            interface = $2
            sub(/@.*/, "", interface)
            split($4, cidr, "/")
            ip_address = cidr[1]
            if (ip_address == route_ip || is_vpn[interface] || tolower(interface) ~ /^(zt|tailscale|wg|tun|tap|ppp)/) {
                if (!(ip_address in selected)) {
                    order[++selected_count] = ip_address
                    selected[ip_address] = ip_address " " cidr[2] " " interface
                }
            }
        }
        END {
            if (route_ip in selected) print selected[route_ip]
            for (i = 1; i <= selected_count; i++)
                if (order[i] != route_ip) print selected[order[i]]
        }
    ' | column -t
end
```

- [ ] **Step 3: Run the complete regression matrix and verify GREEN**

Run `bash tests/rlip4.sh`.

Expected: exit 0 with no output; all eight shell/dependency/route combinations match exactly.

- [ ] **Step 4: Commit the tested behavior**

```bash
git add tests/rlip4.sh tests/fixtures/rlip4-ip common.sh.in common.fish.in
git diff --cached --check
git commit -m "feat(rlip4): show routed and vpn ipv4 addresses"
```

### Task 4: Verify generation, syntax, and the live network result

**Files:**
- Verify: `common.sh.in`
- Verify: `common.fish.in`
- Verify: `tests/rlip4.sh`

- [ ] **Step 1: Run all repository shell tests**

Run:

```bash
for test_file in tests/*.sh; do bash "$test_file"; done
```

Expected: exit 0 with no failure messages.

- [ ] **Step 2: Generate both configurations and check syntax**

Run:

```bash
bash common.sh.in stdout > /tmp/dotzsh-common.sh
bash -n /tmp/dotzsh-common.sh
zsh -n /tmp/dotzsh-common.sh
bash common.fish.in -0 > /tmp/dotzsh-common.fish
fish -n /tmp/dotzsh-common.fish
```

Expected: every command exits 0.

- [ ] **Step 3: Check template lint and whitespace**

Run:

```bash
shellcheck common.sh.in common.fish.in tests/rlip4.sh tests/fixtures/rlip4-ip
git diff --check
```

Expected: no shellcheck errors and no whitespace errors.

- [ ] **Step 4: Verify the generated function against the current host**

Run:

```bash
bash --noprofile --norc -c 'source /tmp/dotzsh-common.sh; rlip4'
```

Expected on the current host: output contains `192.168.1.29` on `enp4s0` and `10.144.2.9` on `ztmosdpe46`, and does not contain `172.17.0.1` on `docker0`.

- [ ] **Step 5: Inspect final scope**

Run:

```bash
git status --short
git log -2 --oneline
git show --stat --oneline HEAD
```

Expected: implementation files are clean, and the latest two commits are the design and the tested `rlip4` implementation.
