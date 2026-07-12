# `rlip6` Route and VPN Address Selection

## Goal

Make `rlip6` show the IPv6 address selected for normal outbound traffic while
always retaining usable global or unique-local IPv6 addresses assigned to
ZeroTier and other VPN or tunnel interfaces.

## Address Selection

`rlip6` will combine two address sets and remove duplicates:

1. The preferred source address selected by `ip -6 route get 2400:3200::1`.
2. Every usable global-scope IPv6 address assigned to an interface identified
   as a VPN or tunnel.

The route lookup only asks the kernel to resolve a route; it does not require
`2400:3200::1` to answer packets. If the lookup fails, qualifying VPN and
tunnel addresses must still be displayed.

## VPN and Tunnel Detection

An interface qualifies when either of these checks succeeds:

- Kernel link metadata identifies it as `tun`, `tap`, `wireguard`, or `ppp`.
- Its name starts with `zt`, `tailscale`, `wg`, `tun`, `tap`, or `ppp`, using
  case-insensitive matching.

Both `link_type` and `linkinfo.info_kind` are considered so custom interface
names remain detectable.

Docker and bridge interfaces are not explicitly blacklisted. They are omitted
unless they are selected as the outbound route or independently qualify as a
tunnel.

## IPv6 Validity Rules

- Only addresses reported with global scope are eligible. This includes ULA
  addresses used by VPNs while excluding link-local `fe80::/10` addresses.
- Deprecated and tentative addresses are excluded.
- The jq implementation reads iproute2's boolean `deprecated` and `tentative`
  properties instead of expecting an IPv4-style flags array.
- Temporary privacy addresses remain eligible and may be selected as the
  outbound source by the kernel.

## Output and Compatibility

Output uses the same three columns as `rlip4`: IPv6 address, prefix length, and
address label or interface name. The behavior must remain equivalent in:

- Bash/zsh and fish generated configuration.
- The `jq` implementation and the Linux fallback used without `jq`.

## Failure Handling

- A failed route lookup produces no primary address but does not suppress VPN
  global or ULA addresses.
- Interfaces with only link-local IPv6 addresses produce no rows.
- An address matching both selection rules appears once.

## Verification

Deterministic tests will use controlled command output to cover:

- A physical interface with stable and temporary IPv6 addresses where only
  the route-selected source is shown.
- VPN global and ULA addresses detected by metadata and name.
- Exclusion of unrelated physical, Docker, link-local, deprecated, and
  tentative addresses.
- VPN-only output when the IPv6 route lookup fails.
- Equivalent generated Bash/zsh and fish behavior, with and without `jq`.
