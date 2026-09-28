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

---

# Follow-up: Playwright Chromium (2026-09-28)

## Goal
Make Chromium launchable so Playwright e2e suites run on this NixOS host.
Layer 1 (`nix-ld.libraries`) is extended with Chromium's dlopen deps.

## Findings (verified 2026-09-28)
- Playwright needs **no** setup change: `tdco-interactive-map` (1.63.0) and
  `CRM/apps/web` (1.62.1) already use bundled Chromium. `devices['Desktop Chrome']`
  in the CRM config is a viewport/UA descriptor, *not* Google Chrome — and no
  system Chrome is installed, so `channel: 'chrome'` would fail anyway.
- Browser binaries are already downloaded: `~/.cache/ms-playwright` has
  `chromium-1243` + `chromium_headless_shell-1243` (tdco) and the `1234` pair
  (CRM). No `npx playwright install` needed.
- **Real blocker:** Chromium will not start —
  `error while loading shared libraries: libnspr4.so`. Both the headless
  shell *and* `channel: 'chromium'` (full binary) fail identically.
- Cause: the module builds a `buildEnv` symlink farm and points
  `NIX_LD_LIBRARY_PATH` at it — `paths = map lib.getLib cfg.libraries`,
  `pathsToLink = [ "/lib" ]`, resolved from
  `/run/current-system/sw/share/nix-ld/lib` (nix-ld 2.0.6 writes no
  `ld.so.conf.d` file; only the `/lib64` tmpfiles symlink exists). Since
  `lib.getLib` picks each package's `lib` output and only `/lib` is ever
  linked, no `dev` output or header can leak in. Present already: glib/gio,
  alsa, xcb + `xcb-*`, udev, pulse,
  libsecret, stdc++, systemd. **Missing** (diffed against
  `/run/current-system/sw/share/nix-ld/lib`): `libnspr4.so`, `libnss3.so`,
  `libnssutil3.so`, `libsmime3.so`, `libatk-1.0.so.0`,
  `libatk-bridge-2.0.so.0`, `libatspi.so.0`, `libdbus-1.so.3`,
  `libexpat.so.1`, `libgbm.so.1`, `libdrm.so.2`, `libX11.so.6`,
  `libXext.so.6`, `libx11-xcb.so.1`, `libXcomposite.so.1`,
  `libXdamage.so.1`, `libXfixes.so.3`, `libXrandr.so.2`,
  `libxkbcommon.so.0`.
- Escape hatches tested and rejected: `nix-shell -p <libs>` fails identically
  (nix-ld ignores `LD_LIBRARY_PATH`); `NIX_LD_LIBRARY_PATH` *is* honored but
  **replaces** the baked list (error moved to `libglib`) so every run must
  restate the whole set; `steam-run` is unfree-gated on this host and pulls
  Steam.

## Decisions
- **F-D1 — Extend Layer 1 `nix-ld.libraries`** with `nspr nss at-spi2-core
  dbus expat libgbm libdrm libX11 libXcomposite libXdamage libXfixes
  libXrandr libxkbcommon`. One rebuild fixes both projects; reuses the
  proven epic-05 mechanism. *Rejected:* per-project `devShell` (dep list
  duplicated across 2 repos), `nix-shell` per run (broken, above),
  `steam-run` (unfree + Steam), `playwright install-deps` (apt/yum only).
- **F-D2 — `libgbm` + `libdrm`, not full `mesa`.** Narrower closure, no
  EGL/wayland driver surface dragged into the nix-ld dir.
- **F-D3 — Still no `wayland`.** Epic-05 D1's constraint holds. If a rebuild
  transitively exposes `libwayland-client`, drop the offending package rather
  than accept an opencode clipboard regression (epic 04 D5).
- **F-D4 — Additive edit only.** `configuration.nix` already carries an
  unstaged change from another epic; touch nothing outside the library list.
- **F-D5 — No second wave; one real gap (`libXext`).** The predicted
  fontconfig/freetype/libcups/libxshmfence gaps did **not** materialise:
  headless Chromium launched at 153.0.8010.12 on the first pass. The single
  follow-up was `libXext`, a *separate* nixpkgs package from `libX11`
  (`nix-ld` links each package's `lib` output, so `libX11` alone does not
  supply it). Verified by simulating the post-rebuild `NIX_LD_LIBRARY_PATH`
  in a temp dir before spending a second rebuild. Note `libX11-xcb.so.1` is
  capital-X and *was* already present via `libX11` — a case-sensitive check
  falsely flagged it.

## Milestones
1. Add the library list; `nix-instantiate --parse` both configs.
2. Rebuild; confirm new libs in `share/nix-ld/lib` and `libwayland-client`
   still absent.
3. Chromium launch smoke (`node -e` launch + `setContent` + version).
4. Run a real suite from `tdco-interactive-map`.
5. Repeat the smoke from `CRM/apps/web`.

## Risks
- Rebuild needs sudo (zenity askpass) — may interrupt.
- Transitive `libwayland-client` regresses epic 04 opencode paste.
- Second-wave dlopen gap (fonts) leaves screenshots blank while navigation passes.
- `configuration.nix` carries unrelated unstaged edits — keep the diff surgical.
