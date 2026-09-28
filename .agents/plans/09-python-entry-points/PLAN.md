# Plan: python entry points via uv itself (no proxy scripts)

## Goal

`python` and `python3` run directly on NixOS (and macOS) using uv's own
machinery — zero wrapper/proxy scripts, no PATH edits, no rebuild.

## Approach

```
uv python install 3 --default   # → ~/.local/bin/python, python3, python3.14
                                #    (uv-managed symlinks; uv re-points them on upgrades)
PATH                            # already covered: common/.bash_profile:12,264
                                #   prepend ~/.local/bin (= uv's bin dir)
uv python update-shell          # NOT run — see Decisions
setup/steps/91-uv-python.sh     # runs the install on fresh machines
README                          # documents where python comes from; pip = uv pip
```

## Decisions

- **uv-native `--default`** — `uv python install 3 --default` is uv's
  supported way to get `python` + `python3` alongside `python3.14`.
  Rejected: the 4 wrapper scripts of the previous draft (the exact proxy
  scripts this ask forbids); nixpkgs `python3` in `configuration.nix` (it has
  *no pip module at all*, a second interpreter vs uv's 3.14, and needs
  sudo + `nixos-rebuild` + the manual `/etc/nixos` copy).
- **Skip `uv python update-shell`** — `~/.local/bin` is already prepended by
  `common/.bash_profile:12,264`, and the rc files are symlinks into this
  repo, so letting uv edit them would dirty `common/`. (update-shell is the
  fallback for machines without our profile.)
- **Fresh machines: setup step `91-uv-python.sh`** — `# requires: uv`,
  `# check: [ -e "$HOME/.local/bin/python" ]`, `# prio: p2`, body
  `uv python install 3 --default`. Rejected: README-only (manual, gets
  forgotten); the `[pip]` group (that installs pipx *packages*, wrong tool).
- **Unpinned (`3` = latest stable)** — matches the repo's no-pin style
  (`packages.list` tracks latest). Rejected: pin `3.14` (goes stale, needs
  manual bumps). Machine-to-machine drift named under Risks.
- **`pip` is deliberately not provided** — uv only ever links `python*`
  executables (docs + `--help` confirm: `--default` adds `python{major}` and
  `python`, never pip). uv's pip-compatible interface is `uv pip …`;
  `python3 -m pip` also works, and bare `pip install` into the interpreter is
  PEP 668-blocked anyway (uv's python ships `EXTERNALLY-MANAGED`). Opt-in if
  wanted: symlinks `pip`/`pip3` → the interpreter's bundled scripts (they
  self-resolve via `realpath`, verified) — but uv won't manage them.

## Milestones

1. `uv python install 3 --default` here → `python` + `python3` appear.
2. Setup step `setup/steps/91-uv-python.sh`.
3. README note (PATH section).
4. Verify: commands, venv precedence, `setup-os --list`, bats suite.

## Milestone 5 (this ask): provision by default on NixOS

```
nixos-rebuild switch
        │  deploys
        ▼
/etc/systemd/user/default.target.wants/uv-python.service   (global enable)
        │  first login (user manager starts default.target)
        ▼
systemd --user: uv-python.service  (oneshot)
  ConditionPathExists=!%h/.local/bin/python   → skipped once provisioned
  ExecStart=${pkgs.uv}/bin/uv python install 3 --default
        │
        ▼
~/.local/bin/{python, python3, python3.14}   ← already on PATH via .bash_profile:12,264
```

- **TODO 5**: add `systemd.user.services.uv-python` to `configuration.nix`;
  syntax-check with `nix-instantiate --parse`.
- **TODO 6**: diff repo `configuration.nix` vs `/etc/nixos/configuration.nix`
  **first** (if /etc has local-only edits → stop and ask), backup, copy,
  `sudo nixos-rebuild switch`.
- **TODO 7**: verify unit enablement, the skip path, and the positive path
  (remove the two links → `systemctl --user start uv-python` → links come
  back), then the bats suite again.

## Risks

- `--default` is **experimental** in uv 0.11.21 — if the flag changes, the
  setup step fails loudly (not silently).
- Version drift: `3` resolves to latest stable at install time; machines
  diverge until the step is re-run.
- macOS: the new unversioned names shadow the Xcode stub `/usr/bin/python3`
  (intended; the step is the fix on a fresh Mac).
- pipx (pre-existing, untouched): venvs' `python3.13` points into
  `/nix/store/…python3-3.13.15` — a rebuild + GC can break `autopep8`/`mdtoc`.
  Optional follow-up: prefer `uv tool install` on NixOS.
- Cosmetic, untouched: PATH carries each entry 3–4× (profile sourced by both
  `.bashrc` and `.zshrc`).
