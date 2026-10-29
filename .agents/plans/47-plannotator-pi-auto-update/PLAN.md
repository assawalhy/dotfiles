# Plan: plannotator pi install fix

**Status: implemented. The auto-update work item (Part 2) was requested and
then removed by the user on 2026-10-26 — do not resurrect it.**

## Goal

Make `pi install npm:@plannotator/pi-extension` work — manually and through
`setup/agent-tools.sh install plannotator`.

## Symptom (verified 2026-10-26)

`pi install npm:@plannotator/pi-extension` dies with:

```
npm error command failed
npm error command sh -c node scripts/prebuild.js || node-gyp rebuild
npm error gyp ERR! build error
npm error gyp ERR! stack Error: not found: make
```

## Root cause

`@plannotator/pi-extension` depends on `node-pty`, which ships no prebuilt
binary for `linux-x64` Node 26. Its install script runs
`node scripts/prebuild.js || node-gyp rebuild` and falls through to a full
`node-gyp` native compile. That needs `make`, `gcc/g++`, and `python3`.

On NixOS `gcc` is present (`stdenv.cc` in `environment.systemPackages`),
`python3` resolves, but **`make` is not on PATH** (`command -v make` is empty;
`gnumake` is not in the profile). node-gyp reports `not found: make` and the
whole install aborts, so the pi extension never lands.

## Fix (implemented)

Two layers, both repo-owned:

1. **`nix/configuration.nix`**: added `gnumake` to `environment.systemPackages`
   (next to `stdenv.cc`). This puts `make` on every PATH — interactive shells,
   the graphical session, and systemd user units — so any native build that
   needs it works. It is the NixOS-idiomatic fix and also unblocks `node-gyp`
   for future pi extensions (context7-pi, node-pty dependents, ...).
2. **`setup/agent-tools.sh`** (`plannotator_pi_install`): prepends `make` when
   running the pi install, so the script keeps working on machines where the
   config change has not been rebuilt yet (fresh clone, or before
   `update-nixos.sh` runs). The lookup is cheap and guarded:

   ```sh
   make_cmd() { command -v make && return; nix eval --raw nixpkgs#gnumake.outPath 2>/dev/null | xargs -I{} printf '%s/bin/make\n' {}; }
   ```

   Resolution order: existing `make` on PATH, else a store-path `make` from
   `nix eval` (no root, no rebuild), else nothing (the install then fails with
   the original error and stays visible).

The store-path fallback is only a bridge until `gnumake` is in the profile;
after the next `update-nixos.sh`, `command -v make` resolves and the fallback
is never taken.

## Manual unblock (one-off, already applied)

```sh
export PATH="$(nix eval --raw nixpkgs#gnumake.outPath 2>/dev/null)/bin:$PATH"
pi install npm:@plannotator/pi-extension
```

This is exactly what `plannotator_pi_install` now does internally.

## Why not add node-gyp's other deps

`node-gyp` also wants `gcc/g++` (already present via `stdenv.cc`) and
`python3` (already resolves to uv's 3.14). `make` was the only missing piece;
adding the others would be dead weight.

## Removed work item (do not resurrect)

An auto-updater for self-updating agents (codex, pi, plannotator, kilo,
opencode, awesome-agent, herdr) was drafted as Part 2: a `systemd` user timer +
`nix/auto-update-agents.sh`, plus dropping `codex` from `systemPackages`. The
user removed it on 2026-10-26. None of that remains in the repo:
`nix/auto-update-agents.sh` is deleted, `codex` is back in
`environment.systemPackages`, and there is no `agent-autoupdate.{service,timer}`.
The `gnumake` addition and the `setup/agent-tools.sh` make bridge are kept —
they are the plannotator fix, independent of the auto-updater.

## Verification (done)

- `pi install npm:@plannotator/pi-extension` with make on PATH → success, pi
  lists the extension.
- `nix eval --raw nixpkgs#gnumake.outPath` works without root/rebuild (bridge
  for the script).
