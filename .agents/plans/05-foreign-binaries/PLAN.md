# Plan: Foreign (non-Nix) binaries on NixOS — hardening

## Goal
Make the foreign binaries the user runs (opencode, claude, npm/pipx/cargo/go
tools, future downloads) work reliably on NixOS, with a repeatable triage path
for new ones. **Not** emulating Arch/Debian host-wide — NixOS is not FHS and
faking it globally is unsupported and non-reproducible.

## Findings (verified 2026-09-25)
- `opencode` and `claude` are foreign ELF binaries (interpreter
  `/lib64/ld-linux-x86-64.so.2`) → they run via **nix-ld**
  (`programs.nix-ld.enable = true`).
- `programs.nix-ld.libraries` was unset, so nix-ld's dir had only the module
  defaults and **no** `libxcb`/`libwayland-client`.
- Failures are runtime `dlopen` libs, invisible to `ldd` (which reports
  `0 not found` for both). Reference scan:
  - opencode → `libxcb`, `libwayland-client`, `glib`/`gobject`, `libsecret`,
    `alsa`, `pulse`, `libstdc++`, `libgcc_s`, `libutil`.
  - claude → `alsa`, `glib`/`gobject`, `libsecret`, musl-libc string.
- Consequence: opencode clipboard dead (epic 04); any other dlopen fails
  silently and degrades a feature.
- FHS-only assumptions absent as expected: `/usr/lib/x86_64-linux-gnu`,
  `/etc/ld.so.cache`, `ldconfig`. `/usr/bin/env` + `/bin/sh` exist;
  `/bin/bash` absent.
- Shebangs in use all resolve today: `/usr/bin/env node|bash`, pipx venv
  absolute pythons.

## Decisions
- **D1 — Layer 1, curated `programs.nix-ld.libraries`.** Add
  `libxcb`, `glib`, `libsecret`, `alsa-lib`, `libpulseaudio` (module defaults
  stay). Covers the opencode/claude dlopens and delivers epic 04's D5 fix in
  one rebuild. **Exclude `wayland`**: adding it re-selects OpenTUI's broken
  Wayland clipboard backend on GNOME (epic 04 D5).
- **D2 — Layer 2, `services.envfs.enable = true`.** Resolves hardcoded
  shebang/interpreter paths (`/bin/bash`, `/usr/bin/python3`, …) via PATH.
  Currently redundant but cheap insurance for future binaries.
- **D3 — Layer 3, triage (documented, not installed).** For a new binary:
  `NIX_LD_LOG=debug <bin>` → `ldd` / `readelf -d` / `LD_DEBUG=libs` → then
  `nix run github:thiagokokada/nix-alien#nix-alien-ld -- <bin>` (auto-resolves
  missing libs) → `nix run github:thiagokokada/nix-alien#nix-alien -- <bin>`
  (FHS shell for absolute-path dlopen / ldconfig).
- **D4 — Layer 4, escape hatch (documented).** `buildFHSEnv`/`steam-run` for
  stubborn or GUI apps; a venv wrapper exporting
  `LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH` for pip/npm native modules.
- **Rejected:** kitchen-sink nix-ld library set (version collisions via
  `ignoreCollisions`, huge closure, re-breaks opencode); host-wide FHS
  (unsupported, non-reproducible); reinstalling opencode from nixpkgs
  (v1.18.31 — a V1 downgrade); `environment.ldso32`/setuid binaries (niche /
  not fixable).

## Milestones
1. `configuration.nix`: Layer 1 libraries + envfs.
2. Rebuild.
3. Verify libs present in `/run/current-system/sw/share/nix-ld/lib` and envfs
   mounted (`/usr/bin/env`, `/bin/bash`).
4. Verify opencode image paste with **no** manual `LD_LIBRARY_PATH`.
5. Commit.

## Risks
- Rebuild needs sudo (zenity askpass).
- envfs swaps `/usr/bin` + `/bin` for a `nofail` FUSE mount; verify after
  switch and revert if `/usr/bin/env` breaks.
- Version collisions: `buildEnv` uses `ignoreCollisions` — keep the list
  curated, never blanket.
- Adding `wayland` later regresses epic 04 — keep the warning comment.
