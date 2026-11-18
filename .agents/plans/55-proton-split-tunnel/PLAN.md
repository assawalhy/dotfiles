# Proton split tunnel through Cloudflare WARP (MASQUE)

## Goal

Proton Mail, Pass, Calendar, Drive and the Proton VPN API work from this NixOS machine in Egypt.
Only Proton domains go through a tunnel.
All other traffic keeps the normal default route.

## Evidence

- DNS is not poisoned. `proton.me`, `pass.proton.me`, `protonvpn.com` time out on 185.70.42.x and 185.159.159.x, so the block is by IP address.
- WireGuard to WARP failed on 28 endpoint and port combinations (162.159.192.1, 162.159.193.1, 188.114.96.1, 188.114.97.1 on ports 500, 854, 864, 2408, 4500, 1701, 443). No handshake. The protocol is dropped.
- `usque socks` (WARP over MASQUE, QUIC on UDP 443) connected in 2 seconds. `proton.me`, `pass.proton.me`, `protonvpn.com` returned 200 and `api.protonvpn.ch` returned 404 through it. Trace showed `warp=on`, colo MRS.

## Approach

```
app -> sing-box tun (system-wide)
         |-- domain_suffix proton.me, protonvpn.com, protonvpn.ch, pm.me, protonmail.com, proton.black, protonmail.ch, proton.ch -> socks outbound 127.0.0.1:1080
         `-- everything else -> direct
usque.service (socks5 on 127.0.0.1:1080, MASQUE to Cloudflare)
```

- `usque` comes from nixpkgs (4.2.1). A systemd service runs `usque socks -b 127.0.0.1 -p 1080` with `-c /var/lib/usque/config.json`.
- `services.sing-box` (1.14.4) runs a tun inbound with auto_route and `final = direct`.
- The usque `config.json` holds the WARP private key. It is copied to `/var/lib/usque/` by hand and never enters the repo.

## Decisions

- D1. MASQUE over WireGuard: WireGuard is blocked on every tested endpoint.
- D2. No VPS: no free server needs no card, and MASQUE already works.
- D3. sing-box with domain rules over IP ranges: Proton's addresses change, domains do not.
- D4. tun inbound over a per-app proxy: Proton VPN, Pass and Mail desktop apps do not all honour proxy settings.
- D5. `final = direct`: the default network setup stays untouched.
- D6. Secrets stay out of the repo: `config.json` is provisioned by hand.

## Rejected

- WARP over WireGuard (`wgcf`): blocked.
- `wgcf` with `AllowedIPs` for Proton ranges: blocked, and IP ranges go stale.
- Oracle or Google VPS with VLESS and Reality: needs a card, and no source confirms Egyptian signups. Kept as the fallback if MASQUE is later blocked.

## Risks

- Egypt may throttle or block QUIC to Cloudflare later. Fallback: `usque --http2` (TCP and TLS), then the VPS option.
- sing-box auto_route may collide with Tailscale and with the existing `networking.firewall.checkReversePath = false` workaround. Check `tailscale status` and a Tailscale ping after the switch.
- Cloudflare IPs are shared. Proton might challenge some of them. Not seen in the test.
- Sing-box DNS must resolve Proton names before routing. A fake-ip or sniff setting is part of item 3.

## Milestones

1. usque service up, socks reachable.
2. sing-box routes only Proton domains.
3. Switch, verify Proton, verify other traffic and Tailscale unchanged.

## Changes found during execution

- The DNS hijack and the Proton DNS server were removed. Hijacking DNS made the `local` resolver send queries from the wrong interface to Tailscale's resolver, and all name resolution failed. Proton is blocked by IP, not by DNS, so the system resolver is enough.
- The tun stack is `gvisor`. With `mixed`, the kernel TCP path dropped every TCP connection and only UDP reached sing-box.
- The tun address is `198.18.0.1/30`. `172.19.0.1/30` overlapped a Docker bridge on `172.19.0.0/16`.
- usque has a fixed uid (970) and the tun uses `exclude_uid`. Without this, usque's long-lived QUIC session to Cloudflare was captured by the tun and stalled ("no recent network activity").
