# Plan: Tailscale for the Herdr mobile app

## Goal

Give the Herdr phone app a route to this machine from outside the LAN. The phone is an SSH client that runs `hc connect` against `herdr-core` here, so the only repo change is making the host a tailnet node.

## What is already true

- `services.openssh.enable = true` and `sshd` is active.
- `herdr-core` 0.1.20 runs from `herdr-app`; `hc` is in `~/.local/bin`.
- Non-interactive SSH sees `~/.local/bin` because `/etc/zshenv` sources `/etc/set-environment`.
- Tailscale is absent. No `authorized_keys` exists. `sshd` offers publickey, password and keyboard-interactive.

## What changes

| File | Change |
|---|---|
| `nix/configuration.nix` | `services.tailscale.enable = true;` next to the openssh line |
| `setup/packages.list` | `tailscale` in `[extra]` for the non-NixOS hosts |
| `.agents/plans/53-tailscale-herdr-mobile/` | this plan and its TODO |

Out of scope: `nixos-rebuild switch`, `sudo tailscale up`, tailnet ACLs, and phone configuration. They need an interactive login and account access.

## Decisions

### D1 System daemon through the NixOS module

`services.tailscale.enable` brings `tailscaled` as a system unit and puts the `tailscale` CLI in `environment.systemPackages`. The daemon survives logout, and login state persists across rebuilds.

Rejected: a user-level `tailscaled` unit, and a hand-downloaded static binary. Both duplicate what the module already wires.

### D2 No firewall change

`services.openssh.enable` already admits `tcp:22` on every interface, `tailscale0` included. The tailscale module's `openFirewall` only opens the UDP tunnel port and defaults to false, which is correct for an outbound NAT-traversal client.

Rejected: `networking.firewall.trustedInterfaces = [ "tailscale0" ]`. It would expose every listening port on the machine to the tailnet for one service that already has a hole.

### D3 Auth stays outside the repo

`tailscale up` is interactive and the ACL lives in the admin console. Nothing about the node key or ACL enters the repository.

Rejected: `services.tailscale.authKeyFile` with a committed secret.

### D4 One `packages.list` entry for the other hosts

`tailscale cask:tailscale pacman:tailscale apt:- p3` in `[extra]`. NixOS is handled by D1; the brew cask and the Arch package are the packaged paths; Ubuntu has no `tailscale` in its own repos, so apt is skipped.

Rejected: no entry at all. The macOS and Arch machines need the same tailnet.

### D5 No Herdr changes

`herdr-core`, `hc`, the SSH PATH and `sshd` are already in place. The phone side is app configuration, and the app starts no daemon here.

Rejected: an autostart unit for `hc server start`. Useful, but it is a separate change and the Herdr app currently starts the core.

### D6 `sshd` passwords off

`PasswordAuthentication = false` and `KbdInteractiveAuthentication = false`. Both are needed: with `UsePAM yes`, keyboard-interactive still accepts the account password even when `PasswordAuthentication` is off.

Rejected: a `Match Address 100.64.0.0/10` exception. It would keep the password path on the tailnet, which is the path the hardening is meant to close.

The change is inert until a switch. `RunSSH` was false and the phone authenticated with a password at 13:46 on 2026-11-11, so a switch before the app moves to its key or Tailscale SSH cuts the phone off.

## Risks

- Default tailnet ACL lets every device in the tailnet reach every port. Restrict to `tcp:22` if other people or shared nodes join.
- `sshd` accepts passwords on this box. A key or Tailscale SSH is stricter.
- `herdr-app` has no autostart. After a reboot the phone connects but finds no core until the app opens.
- A ProtonVPN kill switch can block `tailscaled`. `checkReversePath` is already false, so reverse path filtering is not the obstacle.

## Verification

1. `nix/update-nixos.sh -n` lists only `configuration.nix` as changed.
2. `nix/update-nixos.sh build` finishes with exit 0.
