# Plan: Claude Desktop and Orca on NixOS

**Status: DONE.** Verified by the user 2026-10-18. Drafted 2026-10-17. Progress is in [TODO.md](TODO.md).

## Goal
Install Claude Desktop (Anthropic's official Linux beta) and Orca (stablyai/orca, the multi-agent IDE from onorca.dev) on this NixOS 26.05 host, both launchable from the GNOME app grid.

## Findings (verified 2026-10-17)
- Neither app is in nixpkgs 26.05 (`claude-desktop`, `orca-ide`, `stably-orca` attributes do not exist; `pkgs.orca` is the GNOME screen reader).
- Claude Desktop: Anthropic publishes a Debian repo at `https://downloads.claude.ai/claude-desktop/apt/stable`. The latest amd64 build is `2.42304.0`, sha256 `74cd2ccc29d24165144e455cbc872c6cc2a24a263b83e73420e95f89166d4aa4`.
- `poeck/claude-desktop-nix-flake` (MIT) packages that .deb: dpkg extract, autoPatchelf, and a perl rewrite inside `app.asar` that points the Cowork VM at Nix OVMF firmware and the bundled `virtiofsd`. Its pin is stale (`2.9939.4`, last push 2026-09-28).
- `/dev/kvm` is mode 0666 on this host, so the Cowork VM needs no group change. GNOME portals are already configured.
- Orca: release `v1.4.229` was published today; releases are near daily. Assets include `orca-linux.AppImage` and `latest-linux.yml` for electron-updater.

## Approach
- Claude Desktop: vendor the flake's derivation as `nix/claude-desktop/default.nix`, bump it to `2.42304.0`, and add `(pkgs.callPackage ./claude-desktop { })` to `environment.systemPackages`. `nix/update-nixos.sh` mirrors the whole `nix/` tree, so the relative path deploys.
- Orca (user choice: self-updating AppImage): set `programs.appimage = { enable = true; binfmt = true; }` so an AppImage runs directly, download `orca-linux.AppImage` to `~/Applications/`, and add a desktop entry `common/.local/share/applications/orca-ide.desktop` that execs it. electron-updater rewrites the file at the same `$APPIMAGE` path, so the entry stays valid.
- Orca icon: extract it once from the AppImage (`--appimage-extract`) into `~/.local/share/icons/hicolor/512x512/apps/orca-ide.png`; not committed.

## Decisions
- Vendor the derivation, not the flake input: the config is a non-flake `configuration.nix` (pins via `fetchTarball`), and the flake's pin lags upstream by many versions.
- Keep the perl patch's `or die` guards: an upstream bundle change fails the build with a named error instead of shipping a Cowork VM that cannot find its firmware.
- Orca outside the Nix store: chosen by the user so the in-app updater keeps working. Cost: the binary is not declared in the repo; a fresh machine needs the download step.

## Milestones
1. Claude Desktop builds and launches.
2. Orca AppImage runs from the app grid.

## Risks
- The `2.42304.0` bundle may no longer contain the strings the perl patch matches. Mitigation: build fails loudly; adjust the regexes against the extracted `.vite/build/*.js`.
- Claude Desktop is a beta with no auto-update on Nix; updating means bumping `version` + `hash`.
- Orca's AppImage needs libraries that `appimage-run`'s FHS env may lack; if it fails to start, add them via `programs.appimage.package = pkgs.appimage-run.override { extraPkgs = ...; }`.

## Updates
- Claude Desktop has no in-app updater on Linux (Anthropic ships updates through the apt repo). Added `nix/claude-desktop/update.sh`: it reads `Version` and `SHA256` from the apt `Packages` index for amd64 and arm64 and rewrites `version` and both `hash` values in `default.nix`.
