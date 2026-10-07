# Plan — NixOS config under `nix/` + one deploy script

## Goal
Move `configuration.nix` into `nix/` and add a single script that syncs the
repo's NixOS tree to `/etc/nixos` and rebuilds — no hardcoded repo paths, no
hand-copying, works after a repo move or on a fresh machine.

## Why now
- The config lives at the repo root and already references
  `./nix/copyous-terminal-paste/...`; deploying is a manual `cp` +
  `nixos-rebuild switch` (documented across epics, never scripted).
- Epic 23 needs the copyous patch to travel with the config. Putting the config
  next to the patch makes the whole NixOS tree one self-contained directory.

## Target layout
`nix/`
```
configuration.nix                     # moved from repo root
update-nixos.sh                       # new deploy script
copyous-terminal-paste/terminal-paste.patch
zapfast-uri/…
```
`/etc/nixos/` after a sync (mirror of `nix/`, minus machine files):
```
configuration.nix
copyous-terminal-paste/terminal-paste.patch
zapfast-uri/…
hardware-configuration.nix            # machine-specific — never touched
```

## Decisions
- **D1 Move to `nix/configuration.nix`.** References become
  `imports = [ ./hardware-configuration.nix ]` (resolves at `/etc/nixos`) and
  `patches = [ ./copyous-terminal-paste/terminal-paste.patch ]` (sibling).
  Rejected: commit `hardware-configuration.nix` (machine-specific — every
  NixOS install already generates it in `/etc/nixos`); absolute
  `/etc/nixos/...` path (not portable); keep the old `./nix/...` path (breaks
  the moment the config moves).
- **D2 `nix/update-nixos.sh` mirrors `nix/` → `/etc/nixos`** with
  `rsync -a --delete`, excluding `hardware-configuration.nix`, the script
  itself, and backups; falls back to `cp -a` when rsync is absent (fresh-system
  bootstrap). Rejected: bare `cp` (stale files linger, no excludes); symlink
  `/etc/nixos` → repo (hardware file must stay there, and a root-owned system
  dir in git).
- **D3 Script behaviour.** Timestamped backup of the current
  `/etc/nixos/configuration.nix` before syncing; default action `switch`,
  accepts `build|boot|test|dry-build|dry-activate` and forwards extra args;
  `-n|--dry-run` prints the sync plan and skips the rebuild; `-h|--help`.
  `sudo` is invoked inside for the sync + rebuild, so the user runs it
  unprivileged. Rejected: `switch`-only; requiring the user to `sudo` the whole
  script.
- **D4 Declare `rsync` in `environment.systemPackages`** so the fast path works
  after the first deploy; the `cp` fallback covers the very first run.
- **D5 Docs.** Update AGENTS.md ("Setup Package System") to point at
  `nix/configuration.nix` and document `nix/update-nixos.sh`. Rejected for now:
  symlinking the script into `~/bin` (it is a repo tool, run in place).

## Verification
- Sync to a temp dir + the machine's `hardware-configuration.nix`, then
  `nixos-rebuild build -I nixos-config=<tmp>/configuration.nix` → exit 0.
- The built `copyous@9` extension is byte-identical to the reference patched
  tree.
- `nix/update-nixos.sh -n` prints the intended sync and touches nothing.
- The real `switch` + re-login is handed to the user (this container blocks
  `sudo`).

## Risks
- `--delete` removes hand-edits in `/etc/nixos` that are not in the repo.
  Mitigated by the excludes, the timestamped config backup, and `-n`.
- Moving the config invalidates doc/plan references to the root path — handled
  in D5.
- The user's uncommitted `environment.localBinInPath` edit rides along with the
  move (unchanged content).
