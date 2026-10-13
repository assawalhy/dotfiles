# 35 openssl in the system profile

## Goal

`openssl` is not on PATH on this host. Add it to the NixOS system profile so the
CLI is available in every shell, and record the change in the dotfiles.

## State on this host (verified)

- NixOS (`/etc/NIXOS` exists), so `setup-os` skips system-scope managers and every
  system package belongs in `nix/configuration.nix`.
- `command -v openssl` returns nothing. Nothing in `environment.systemPackages`,
  nothing in `/run/current-system/sw/bin`, nothing in `~/.nix-profile/bin`.
- `openssl-3.6.4` is already realised in the store (`openssl-3.6.4-bin`) as a
  dependency of something else. Adding it to the system profile costs a profile
  relink, not a build.

## What to change

1. `nix/configuration.nix`: one entry in `environment.systemPackages`, in the
   `## [terminal]` block next to the other CLI tools.

   ```nix
   openssl
   ```

   A short comment naming the reason: the CLI is what scripts and `curl --cacert`
   style invocations want, while `environment.systemPackages` gives the plain
   `openssl` binary (not the `.dev` output with headers, which `stdenv.cc` covers
   for compiling against).

2. Not `setup/packages.list`. The user dropped that step. This host is NixOS,
   where `setup-os` skips system-scope managers anyway, and macOS ships
   LibreSSL.

## Side effect to accept before switching

The working tree already carries two uncommitted `nix/` changes: an
`xdg-desktop-portal` overlay patch for the Discord screen-share cursor mode
(plan 33) with a version guard that throws, and `libxi` added to the nix-ld
library list. `nix/update-nixos.sh` activates both in the same switch as openssl.
The user was told and chose the rebuild route.

## Verification

1. `nix/update-nixos.sh` (sync, then `sudo nixos-rebuild switch`).
2. `command -v openssl` resolves to a `/nix/store/...-openssl-3.6.4/bin/openssl`.
3. `openssl version` prints `OpenSSL 3.6.4`.
4. `openssl s_client -connect example.com:443 -servername example.com </dev/null`
   completes the handshake, which proves the CA bundle resolves too.

## Rejected alternatives

| alternative | why not |
|---|---|
| `nix profile install nixpkgs#openssl` | Available in seconds, no sudo, no rebuild. But it lives outside the dotfiles, so a profile reset or a fresh host drops it silently. The repo convention is that system packages are declared. |
| `nix shell nixpkgs#openssl -- cmd` | No install, no persistence. Fine for one command, not for a tool other scripts assume. |
| `openssl.dev` in systemPackages | Pulls headers into a system profile nobody compiles against. `stdenv.cc` already covers the build side. |
| Entry in `setup/packages.list` | Rejected by the user; also inert on NixOS. |