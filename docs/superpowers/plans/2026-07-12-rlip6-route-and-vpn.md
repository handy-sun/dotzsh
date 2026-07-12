# `rlip6` Route and VPN Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `rlip6` print the IPv6 selected for traffic to `2400:3200::1` plus every usable global or ULA address on ZeroTier, Tailscale, WireGuard, TUN, TAP, or PPP interfaces.

**Architecture:** Keep `rlip6` self-contained in each generated shell. Combine the route-selected source with valid global-scope VPN addresses detected from kernel metadata and interface-name prefixes, deduplicate by IPv6 address, and exclude link-local, deprecated, and tentative addresses. Exercise Bash/zsh and fish implementations in both jq and jq-free environments through deterministic fake iproute2 output.

**Tech Stack:** Bash, fish, iproute2 output formats, jq, awk, column

---

## File Map

- Create `tests/rlip6.sh`: generated-shell integration matrix for route success and failure.
- Create `tests/fixtures/rlip6-ip`: deterministic IPv6 route, link, and address output.
- Modify `common.sh.in`: jq and jq-free Bash/zsh implementations.
- Modify `common.fish.in`: jq and jq-free fish implementations.

### Task 1: Add the IPv6 regression matrix

**Files:**
- Create: `tests/rlip6.sh`
- Create: `tests/fixtures/rlip6-ip`
- Test: `tests/rlip6.sh`

- [ ] **Step 1: Write the failing integration test**

Create `tests/rlip6.sh`:

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
```

Create `tests/fixtures/rlip6-ip`:

```bash
#!/usr/bin/env bash
set -euo pipefail

route_mode=${MOCK_ROUTE_MODE:-success}

case "$*" in
    '-j -6 route get 2400:3200::1')
        [[ "$route_mode" == success ]] || exit 2
        printf '%s\n' '[{"dst":"2400:3200::1","gateway":"fe80::1","dev":"enp4s0","prefsrc":"2001:db8:1::abcd"}]'
        ;;
    '-j -d -6 addr')
        printf '%s\n' '[
          {"ifname":"lo","link_type":"loopback","addr_info":[{"family":"inet6","local":"::1","prefixlen":128,"scope":"host"}]},
          {"ifname":"enp4s0","link_type":"ether","addr_info":[
            {"family":"inet6","local":"2001:db8:1::abcd","prefixlen":64,"scope":"global","temporary":true},
            {"family":"inet6","local":"2001:db8:1::1","prefixlen":64,"scope":"global"},
            {"family":"inet6","local":"2001:db8:1::dead","prefixlen":64,"scope":"global","deprecated":true},
            {"family":"inet6","local":"fe80::1","prefixlen":64,"scope":"link"}
          ]},
          {"ifname":"enp5s0","link_type":"ether","addr_info":[{"family":"inet6","local":"2001:db8:2::2","prefixlen":64,"scope":"global"}]},
          {"ifname":"zt6","link_type":"ether","linkinfo":{"info_kind":"tun"},"addr_info":[
            {"family":"inet6","local":"fd00:144::9","prefixlen":64,"scope":"global"},
            {"family":"inet6","local":"fe80::9","prefixlen":64,"scope":"link"}
          ]},
          {"ifname":"corp0","link_type":"none","linkinfo":{"info_kind":"wireguard"},"addr_info":[
            {"family":"inet6","local":"fd66::2","prefixlen":64,"scope":"global"},
            {"family":"inet6","local":"fd66::dead","prefixlen":64,"scope":"global","deprecated":true}
          ]},
          {"ifname":"vpn42","link_type":"ppp","addr_info":[{"family":"inet6","local":"fd77::2","prefixlen":128,"scope":"global"}]},
          {"ifname":"tailscale0","link_type":"none","addr_info":[
            {"family":"inet6","local":"fd7a:115c:a1e0::2","prefixlen":128,"scope":"global"},
            {"family":"inet6","local":"fd7a:115c:a1e0::bad","prefixlen":128,"scope":"global","tentative":true}
          ]},
          {"ifname":"docker0","link_type":"ether","linkinfo":{"info_kind":"bridge"},"addr_info":[{"family":"inet6","local":"fd17::1","prefixlen":64,"scope":"global"}]}
        ]'
        ;;
    '-6 route get 2400:3200::1')
        [[ "$route_mode" == success ]] || exit 2
        printf '%s\n' '2400:3200::1 via fe80::1 dev enp4s0 src 2001:db8:1::abcd metric 100'
        ;;
    '-o link show type tun')
        printf '%s\n' '4: zt6: <BROADCAST,UP,LOWER_UP> mtu 2800'
        ;;
    '-o link show type wireguard')
        printf '%s\n' '5: corp0: <POINTOPOINT,UP,LOWER_UP> mtu 1420'
        ;;
    '-o link show type ppp')
        printf '%s\n' '6: vpn42: <POINTOPOINT,UP,LOWER_UP> mtu 1500'
        ;;
    '-o -6 addr show scope global')
        printf '%s\n' \
            '2: enp4s0 inet6 2001:db8:1::abcd/64 scope global temporary' \
            '2: enp4s0 inet6 2001:db8:1::1/64 scope global' \
            '2: enp4s0 inet6 2001:db8:1::dead/64 scope global deprecated' \
            '3: enp5s0 inet6 2001:db8:2::2/64 scope global' \
            '4: zt6 inet6 fd00:144::9/64 scope global' \
            '5: corp0 inet6 fd66::2/64 scope global' \
            '5: corp0 inet6 fd66::dead/64 scope global deprecated' \
            '6: vpn42 inet6 fd77::2/128 scope global' \
            '7: tailscale0 inet6 fd7a:115c:a1e0::2/128 scope global' \
            '7: tailscale0 inet6 fd7a:115c:a1e0::bad/128 scope global tentative' \
            '8: docker0 inet6 fd17::1/64 scope global'
        ;;
    *)
        printf 'unexpected mock ip arguments: %s\n' "$*" >&2
        exit 64
        ;;
esac
```

- [ ] **Step 2: Run the test and verify RED**

Run `bash tests/rlip6.sh`.

Expected: FAIL in `sh/jq route success` because the current implementation calls `ip -j -6 addr` and enumerates addresses instead of selecting the routed source plus VPN addresses.

### Task 2: Implement the jq branches

**Files:**
- Modify: `common.sh.in` in the jq `rlip6` function
- Modify: `common.fish.in` in the jq `rlip6` function
- Test: `tests/rlip6.sh`

- [ ] **Step 1: Replace the Bash/zsh jq implementation**

```bash
rlip6() {
    local route_ip
    route_ip=$(ip -j -6 route get 2400:3200::1 2>/dev/null | jq -r '.[0] | .prefsrc // .src // empty' 2>/dev/null)
    ip -j -d -6 addr | jq -r --arg route_ip "$route_ip" '
        [
            .[]
            | .ifname as $name
            | (.link_type // "") as $link_type
            | (.linkinfo.info_kind // "") as $kind
            | (
                ($link_type | test("^(tun|tap|wireguard|ppp)$"; "i"))
                or ($kind | test("^(tun|tap|wireguard|ppp)$"; "i"))
                or ($name | test("^(zt|tailscale|wg|tun|tap|ppp)"; "i"))
              ) as $is_vpn
            | .addr_info[]?
            | select(
                .family == "inet6"
                and .scope == "global"
                and ((.deprecated // false) | not)
                and ((.tentative // false) | not)
                and (.local == $route_ip or $is_vpn)
              )
            | { local, prefixlen, label: (.label // $name) }
        ]
        | unique_by(.local)
        | sort_by(if .local == $route_ip then 0 else 1 end)
        | .[]
        | "\(.local) \(.prefixlen) \(.label)"
    ' | column -t
}
```

- [ ] **Step 2: Replace the fish jq implementation**

```fish
function rlip6 -d "List routed and VPN IPv6 addresses"
    set -l route_ip (ip -j -6 route get 2400:3200::1 2>/dev/null | jq -r '.[0] | .prefsrc // .src // empty' 2>/dev/null)
    ip -j -d -6 addr | jq -r --arg route_ip "$route_ip" '
        [
            .[]
            | .ifname as $name
            | (.link_type // "") as $link_type
            | (.linkinfo.info_kind // "") as $kind
            | (
                ($link_type | test("^(tun|tap|wireguard|ppp)$"; "i"))
                or ($kind | test("^(tun|tap|wireguard|ppp)$"; "i"))
                or ($name | test("^(zt|tailscale|wg|tun|tap|ppp)"; "i"))
              ) as $is_vpn
            | .addr_info[]?
            | select(
                .family == "inet6"
                and .scope == "global"
                and ((.deprecated // false) | not)
                and ((.tentative // false) | not)
                and (.local == $route_ip or $is_vpn)
              )
            | { local, prefixlen, label: (.label // $name) }
        ]
        | unique_by(.local)
        | sort_by(if .local == $route_ip then 0 else 1 end)
        | .[]
        | "\(.local) \(.prefixlen) \(.label)"
    ' | column -t
end
```

- [ ] **Step 3: Run the matrix**

Run `bash tests/rlip6.sh`.

Expected: both jq shells reach the expected output; jq-free execution remains red because it still uses the old blacklist.

### Task 3: Implement the jq-free branches

**Files:**
- Modify: `common.sh.in` in the Linux fallback `rlip6` function
- Modify: `common.fish.in` in the Linux fallback `rlip6` function
- Test: `tests/rlip6.sh`

- [ ] **Step 1: Replace the Bash/zsh jq-free implementation**

```bash
rlip6() {
    local route_ip vpn_interfaces
    route_ip=$(ip -6 route get 2400:3200::1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')
    vpn_interfaces=$(
        for kind in tun wireguard ppp; do
            ip -o link show type "$kind" 2>/dev/null
        done | awk -F': ' '{ sub(/@.*/, "", $2); print $2 }'
    )
    ip -o -6 addr show scope global | awk -v route_ip="$route_ip" -v vpn_interfaces="$vpn_interfaces" '
        BEGIN {
            count = split(vpn_interfaces, interfaces, "\n")
            for (i = 1; i <= count; i++) is_vpn[interfaces[i]] = 1
        }
        {
            interface = $2
            sub(/@.*/, "", interface)
            split($4, cidr, "/")
            ip_address = cidr[1]
            invalid = 0
            for (i = 1; i <= NF; i++)
                if ($i == "deprecated" || $i == "tentative") invalid = 1
            if (!invalid && (ip_address == route_ip || is_vpn[interface] || tolower(interface) ~ /^(zt|tailscale|wg|tun|tap|ppp)/)) {
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

- [ ] **Step 2: Replace the fish jq-free implementation**

```fish
function rlip6 -d "List routed and VPN IPv6 addresses"
    set -l route_ip (ip -6 route get 2400:3200::1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')
    set -l vpn_interfaces (
        for kind in tun wireguard ppp
            ip -o link show type "$kind" 2>/dev/null
        end | awk -F': ' '{ sub(/@.*/, "", $2); print $2 }'
    )
    ip -o -6 addr show scope global | awk -v route_ip="$route_ip" -v vpn_interfaces="$(string join \n $vpn_interfaces)" '
        BEGIN {
            count = split(vpn_interfaces, interfaces, "\n")
            for (i = 1; i <= count; i++) is_vpn[interfaces[i]] = 1
        }
        {
            interface = $2
            sub(/@.*/, "", interface)
            split($4, cidr, "/")
            ip_address = cidr[1]
            invalid = 0
            for (i = 1; i <= NF; i++)
                if ($i == "deprecated" || $i == "tentative") invalid = 1
            if (!invalid && (ip_address == route_ip || is_vpn[interface] || tolower(interface) ~ /^(zt|tailscale|wg|tun|tap|ppp)/)) {
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

- [ ] **Step 3: Run the complete matrix and verify GREEN**

Run `bash tests/rlip6.sh`.

Expected: exit 0 with no output for all eight shell, dependency, and route combinations.

- [ ] **Step 4: Commit the implementation**

```bash
git add common.sh.in common.fish.in tests/rlip6.sh tests/fixtures/rlip6-ip
git diff --cached --check
git commit -m "feat(rlip6): show routed and vpn ipv6 addresses"
```

### Task 4: Verify generated syntax and live IPv6 behavior

**Files:**
- Verify: `common.sh.in`
- Verify: `common.fish.in`
- Verify: `tests/rlip6.sh`

- [ ] **Step 1: Run every repository shell test**

Run `for test_file in tests/*.sh; do bash "$test_file"; done`.

Expected: exit 0 with no failure messages.

- [ ] **Step 2: Generate and parse all shell configurations**

```bash
bash common.sh.in stdout > /tmp/dotzsh-common.sh
bash -n /tmp/dotzsh-common.sh
zsh -n /tmp/dotzsh-common.sh
bash common.fish.in -0 > /tmp/dotzsh-common.fish
fish -n /tmp/dotzsh-common.fish
```

Expected: every command exits 0.

- [ ] **Step 3: Check scoped lint and whitespace**

```bash
shellcheck tests/rlip6.sh tests/fixtures/rlip6-ip
shellcheck -e SC2006,SC2046,SC2116,SC2086,SC2016 common.sh.in common.fish.in
git diff --check
```

Expected: no new ShellCheck or whitespace errors.

- [ ] **Step 4: Verify the current host result**

```bash
bash --noprofile --norc -c 'source /tmp/dotzsh-common.sh; rlip6'
```

Expected on the current host: exactly the route-selected temporary IPv6 on `enp4s0`; the stable secondary address and ZeroTier's link-local-only IPv6 are absent.

- [ ] **Step 5: Inspect final scope**

```bash
git status --short
git log -3 --oneline
git show --stat --oneline HEAD
```

Expected: implementation files are clean and the latest commit contains only `rlip6` templates and tests.
