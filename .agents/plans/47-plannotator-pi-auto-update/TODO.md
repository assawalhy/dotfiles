# 47-plannotator-pi-auto-update

- [x] nix/configuration.nix: add `gnumake` to systemPackages (Part 1)
- [x] setup/agent-tools.sh: make_cmd() bridge + prepend make in
      plannotator_pi_install (Part 1)
- [x] verify `pi install npm:@plannotator/pi-extension` succeeds with make
      on PATH; pi lists the extension
- [x] auto-update work item removed per user request 2026-10-26:
      deleted nix/auto-update-agents.sh, reverted codex removal + timer/service

## Verified 2026-10-26

- pi install node-pty failure is exactly `not found: make` (NixOS has gcc via
  stdenv.cc, no make on PATH).
- With gnumake bin on PATH, `pi install npm:@plannotator/pi-extension`
  succeeds; pi lists the extension.
- `nix eval --raw nixpkgs#gnumake.outPath` gives the store make without
  root/rebuild (bridge for the script).

## Removed

The auto-update draft (Part 2) is gone: systemd user timer/service,
nix/auto-update-agents.sh, and the codex systemPackages removal. Do not
resurrect without the user asking.
