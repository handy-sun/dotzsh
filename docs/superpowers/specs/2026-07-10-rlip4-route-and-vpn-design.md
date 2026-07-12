# `rlip4` Route and VPN Address Selection

## Goal

Make `rlip4` show the IPv4 address selected for normal outbound traffic while
always retaining IPv4 addresses assigned to ZeroTier and other VPN or tunnel
interfaces.

## Address Selection

`rlip4` will combine two address sets and remove duplicates:

1. The preferred source address selected by `ip route get 223.5.5.5`.
2. Every IPv4 address assigned to an interface identified as a VPN or tunnel.

The route lookup only asks the kernel to resolve a route; it does not require
`223.5.5.5` to answer packets. If the lookup fails, VPN and tunnel addresses
must still be displayed.

## VPN and Tunnel Detection

An interface qualifies when either of these checks succeeds:

- Kernel link metadata identifies it as `tun`, `tap`, `wireguard`, or `ppp`.
- Its name starts with `zt`, `tailscale`, `wg`, `tun`, `tap`, or `ppp`, using
  case-insensitive matching.

The metadata check recognizes custom-named interfaces. The name check covers
VPN implementations whose kernel metadata is generic or inconsistent.

Docker and bridge interfaces are not explicitly blacklisted. They are omitted
unless they are selected as the outbound route or independently qualify as a
tunnel. This avoids incorrectly excluding a host's real `br0` uplink.

## Output and Compatibility

Output retains the existing three columns: IPv4 address, prefix length, and
address label or interface name. The behavior must remain equivalent in:

- Bash/zsh and fish generated configuration.
- The `jq` implementation and the Linux fallback used without `jq`.

## Failure Handling

- A failed route lookup produces no primary address but does not suppress VPN
  addresses.
- Interfaces without IPv4 addresses produce no rows.
- An address matching both selection rules appears once.

## Verification

Deterministic tests will use controlled command output to cover:

- A physical default-route address plus inactive-route ZeroTier and WireGuard
  addresses.
- Exclusion of Docker and unrelated physical interfaces.
- Recognition of a custom-named tunnel through kernel metadata.
- VPN-only output when route lookup fails.
- Equivalent generated Bash/zsh and fish behavior, with and without `jq`.
