# TODO

- [x] configuration.nix: `programs.nix-ld.libraries = with pkgs; [ libxcb glib libsecret alsa-lib libpulseaudio ]`
- [x] configuration.nix: `services.envfs.enable = true`
- [x] `nix-instantiate --parse configuration.nix` (repo + /etc/nixos)
- [x] apply config to `/etc/nixos/configuration.nix` (backup bak-20260925-231149; lazygit hunk excluded — other epic)
- [x] rebuild (`nixos-rebuild switch`, sudo/zenity askpass) — exit 0
- [x] verify `libxcb/glib/libsecret/alsa/pulse` in `/run/current-system/sw/share/nix-ld/lib` (wayland absent)
- [x] verify envfs: `/usr/bin/env` + `/bin/bash` resolve (`fuse envfs` on /usr/bin + /bin; `bash -c` ok)
- [x] verify opencode image paste with no manual `LD_LIBRARY_PATH` → `[Image 1]`
- [x] update epic 04 (D5 delivered via this epic)

## Playwright Chromium follow-up (2026-09-28)

- [x] `configuration.nix`: add `nspr nss at-spi2-core dbus expat libgbm libdrm
      libX11 libXcomposite libXdamage libXfixes libXrandr libxkbcommon` to
      `programs.nix-ld.libraries` (keep the wayland warning comment)
- [x] `nix-instantiate --parse configuration.nix` (repo + /etc/nixos)
- [x] rebuild (`nixos-rebuild switch`, sudo/zenity askpass) — exit 0
- [x] verify new libs in `/run/current-system/sw/share/nix-ld/lib` (16/18; `libXext` + case-mismatch `libX11-xcb` explained)
- [x] verify `libwayland-client*` still ABSENT there (epic 04 D5 guard) — 0 files
- [x] chromium launch smoke — 153.0.8010.12 via simulated `NIX_LD_LIBRARY_PATH`
- [x] second-wave dlopen gaps — none; added `libXext` (separate pkg from `libX11`)
- [x] rebuild #2 with `libXext` — exit 0
- [x] verify all 19 libs in `/run/current-system/sw/share/nix-ld/lib`
- [x] verify `libwayland-client*` still ABSENT — 0 files
- [x] REAL chromium smoke, no env override — 153.0.8010.12
- [x] run one real spec: `tdco-interactive-map` e2e/labels.spec.ts — 4 passed (9.6s)
- [x] chromium launch smoke in `CRM/apps/web` — 151.0.7922.34
- [x] final verification: `bats tests/link-files.bats` 99 ok / 0 not ok;
      `bats tests/select.bats` all ok; `link-known-issues.bats` still all
      fail by design (4 documented bugs untouched)

## OpenCode Desktop AppImage (2026-10-03)

- [x] download 2.0.22 AppImage → `~/Applications/opencode-desktop.AppImage`;
      sha512 matches updater feed
- [x] `nix profile install nixpkgs#appimage-run`
- [x] wrapper `~/.local/bin/opencode-desktop` (executable)
- [x] `.desktop` entry + icon + `x-scheme-handler/opencode` registered
- [x] launch smoke: process alive ≥15 s, no missing-lib errors
- [x] user confirms window opens / GNOME launcher entry
- [x] final: record installed version + update command in PLAN.md
