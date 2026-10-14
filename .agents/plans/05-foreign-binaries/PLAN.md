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

---

# Follow-up: OpenCode Desktop AppImage (2026-10-03)

## Goal
Install the **latest** OpenCode Desktop (V2) for the current user on this
NixOS host, launchable from GNOME. No sudo, no system rebuild.

## Findings (verified 2026-10-03)
- Latest desktop build is **2.0.22** (released 2026-10-02) at
  `opencode.ai/files/bin/2.0.22/opencode-desktop-linux-x86_64.AppImage`
  (245,258,790 bytes); the updater feed
  `https://opencode.ai/update/api/latest/desktop/opencode/latest-linux.yml`
  publishes its **sha512** (`WF+y1xag…ddqA==`).
- `opencode.ai/v2/docs` download links are stale (2.0.6); the feed above is
  authoritative for "latest".
- nixpkgs is **not** an option for V2: stable 26.05 `opencode-desktop` is
  1.15.10, unstable/master 1.18.34 — both V1 (extends this epic's existing
  "V1 downgrade" rejection).
- The upstream repo flake v2.0.22 exposes `opencode-desktop`, but it builds
  from source (bun + electron-builder), uncached — heavy local build.
- `appimage-run` is in nixpkgs; user registry `flake:nixpkgs` → unstable;
  profile already holds `nix profile` installs (nethogs, unzip, zapfast).
- `~/.local/bin` and `~/.nix-profile/bin` are on PATH; `zapfast.desktop`
  shows the local desktop-entry convention.
- Launch behavior (verified): the app bundles its own CLI
  (`~/.config/ai.opencode.desktop/cli/2.0.22/opencode-cli serve --service`)
  and **takes over the shared background service** (port 49374). Each launch
  restarts the service once; sessions reconnect. Observed 3/3.
- The AppImage's own desktop entry runs `AppRun --no-sandbox %U`; the wrapper
  mirrors `--no-sandbox`. Runs as native Wayland (Electron 44, ozone-wayland).

## Decisions
- **AD1 — Official AppImage at `~/Applications/opencode-desktop.AppImage`,
  sha512-verified against the feed.** Latest V2, official artifact.
  *Rejected:* nixpkgs (V1), repo flake build (heavy/uncached), .deb/.rpm
  (need FHS anyway, no gain), flatpak (not enabled, system rebuild).
- **AD2 — `nix profile install nixpkgs#appimage-run`.** The FHS escape hatch
  for GUI apps (this epic's D4); user-scope, no rebuild.
- **AD3 — User-scope integration:** wrapper
  `~/.local/bin/opencode-desktop`, desktop entry
  `~/.local/share/applications/opencode-desktop.desktop` (+
  `x-scheme-handler/opencode`), icon in hicolor.
- **AD4 — Updates = re-download latest AppImage + verify sha512.** Whether
  electron-updater fires under appimage-run is unverified (needs the
  `APPIMAGE` env var); don't promise it. No helper script yet.

## Update recipe (recorded 2026-10-03, installed 2.0.22)
```sh
feed=https://opencode.ai/update/api/latest/desktop/opencode/latest-linux.yml
ver=$(curl -fsSL "$feed" | awk '/^version:/{print $2}')
curl -fL -o ~/Applications/opencode-desktop.AppImage \
  "https://opencode.ai/files/bin/$ver/opencode-desktop-linux-x86_64.AppImage"
# then compare sha512 to the feed's AppImage entry (base64 -> hex) and relaunch
```

## Milestones
1. Download + sha512 verify.
2. Install appimage-run.
3. Wrapper + .desktop + icon + scheme handler.
4. Launch smoke (process alive, no missing-lib errors).
5. User confirms window/launcher entry.

## Risks
- Launch hands over the shared service (see Findings) — active TUI/agent
  sessions reconnect; avoid launching mid-critical-run.
- Auto-update may not fire under appimage-run — manual re-download documented.
- 245 MB download + ~245 MB extracted cache (`~/.cache/appimage-run/`).
- Resolved: sandbox (upstream `--no-sandbox`, mirrored) and Wayland
  (native ozone-wayland confirmed).

---

# Follow-up: Hermes Agent install failures (2026-10-11)

## Goal
Finish the `NousResearch/hermes-agent` install that failed at the `products`
stage on 2026-10-08, and install the `cua-driver` tool that failed
verification. Same Layer 1 / Layer 2 mechanism as this epic.

## Findings (verified 2026-10-11)

Two independent failures. Receipt:
`~/.hermes/telemetry/shared_metrics/pending_installs/4417def8….json` reads
`outcome: failed`, `failed_stage: products`. The Python side installed fine
(`hermes --version` → `v0.21.6+130.g25a71a7`); `node_modules/` is absent, so
the TUI and web products were never built.

**F-H1 — `products` stage: envfs phantom `/bin/npm`.**
`scripts/build/node-deps.mjs:19` walks every `PATH` entry and calls
`realpathSync(bin)` unguarded on any `npm` where `existsSync(bin)` passed.
On this host `/bin` and `/usr/bin` are `envfs` FUSE mounts (epic-05 D2). Their
name index reports `/bin/npm`, `/bin/node`, `/bin/git`, `/bin/python`, `/bin/ls`
as existing while `realpathSync` on them throws ENOENT, so the build died:

```
Error: ENOENT: no such file or directory, lstat '/bin/npm'
    at realpathSync (node:fs:3315:29)
    at npmCommand (node-deps.mjs:19:30)
```

It is not a blanket FUSE lie: `existsSync('/bin/zzz-not-a-real-binary')` is
`false` and `existsSync('/bin/nonexistentdir/file')` is `false`, so the index
holds real names whose targets no longer resolve. `readdirSync('/bin')` returns
0 entries. A working npm exists at `/run/current-system/sw/bin/npm` →
`…nodejs-slim-24.21.0-npm/…/npm-cli.js`. Nothing in the hermes build code adds
`/bin` to PATH (`scripts/build/launchers.py:43` only prepends its own tool
dirs), so the entry came from the environment the Oct-8 installer inherited.

**F-H2 — `cua-driver`: `libXi.so.6` missing.** Reproduced exactly through the
nix-ld interpreter: `/lib64/ld-linux-x86-64.so.2 <cua-driver> --version` →
`error while loading shared libraries: libXi.so.6`. Plain `ldd` reports
`libX11.so.6`, `libXi.so.6` and `libxkbcommon.so.0` as not found, but that is
misleading here: there is no `/etc/ld.so.conf`, and nix-ld resolves through
`/run/current-system/sw/share/nix-ld/lib`, where `libX11` and `libxkbcommon`
already are present. `libXi` is the only real gap. Proven by running the
cached tarball's binary with the store `libxi` on the path: `cua-driver 0.21.0`.
libXi's own `DT_NEEDED` (`libX11`, `libXext`, `libxcb`, `libXau`, `libXdmcp`)
all resolve through nix-ld today, so one package closes it.

**Not a bug:** `~/.hermes/.hermes-update-in-progress.lock` is a sidecar the
checkout never deletes; `tests/scripts/desktop_update/test_desktop_update_posix_marker_corpus.py:90`
asserts it survives.

## Decisions
- **HD1 — Add `libxi` to `programs.nix-ld.libraries`.** Same additive Layer 1
  edit as the Chromium follow-up (F-D1); no `dev` output, no new rebuild
  beyond the one we need anyway. *Rejected:* `LD_LIBRARY_PATH` wrapper (this
  epic's own F-D5 / Risks note: mixed store generations pull a mismatched
  glibc), `nix-alien-ld` (D3 already rejected as per-binary triage), skipping
  the tool outright (drops a default tool `hermes setup` asked for).
- **HD2 — Fix `products` by rebuilding it, not by patching `node-deps.mjs`.**
  The checkout is under `hermes update` management, which does
  `git reset --hard origin/main`, so a local patch to `node-deps.mjs` would be
  silently reverted. Re-running the install from a shell whose PATH has no
  `/bin` avoids the phantom entirely, and the current shell already has none.
- **HD3 — envfs stays enabled; revisit only if the phantom recurs.** Disabling
  it is the durable kill for F-H1, but epic-05 D2 made it load-bearing for
  hardcoded `#!/usr/bin/env` and `/bin/bash` shebangs in foreign binaries, and
  epics 04 and 17 depend on that layer. Trading those for a build-time
  workaround is the wrong default. **Open decision for the user** — see the
  approval ask.
- **HD4 — Report the `node-deps.mjs` bug upstream.** `realpathSync` at line 19
  needs a try/catch so an unresolvable PATH entry is skipped like any other.
  NousResearch/hermes-agent. Informational; not a blocker.

## Milestones
1. `nix/configuration.nix`: add `libxi`; `nix-instantiate --parse` both copies.
2. `nix/update-nixos.sh` rebuild.
3. Verify `libXi.so.6` in `/run/current-system/sw/share/nix-ld/lib` and that
   `libwayland-client*` is still absent (epic-04 D5 guard).
4. `hermes pm install cua-driver`; verify the staged entry passes.
5. Re-run the installer to a clean `products` stage; verify `node_modules/`
   exists and the TUI launches.
6. Report F-H1 upstream.

## Risks
- Rebuild needs sudo (zenity askpass) and may interrupt.
- `libxi` transitively exposing `libwayland-client` would regress epic-04
  opencode paste — checked at step 3, same guard as F-D3.
- Step 5 runs a full `npm ci` (large download, minutes). Queued through `ajq`.
- If `/bin` reappears on PATH in a future shell, the phantom returns and
  `hermes update` fails the same way. HD3 leaves that unfixed by choice.
