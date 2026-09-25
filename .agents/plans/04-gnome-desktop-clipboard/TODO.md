# TODO

- [x] Confirm "desktop icon" scope (user: all — background, app grid, dock)
- [x] configuration.nix: add gnomeExtensions.desktop-icons-ng-ding
- [x] configuration.nix: dconf org/gnome/shell enabled-extensions = ding@rastersoft.com
- [x] configuration.nix: add wl-clipboard + mousepad (sync with packages.list)
- [x] Ghostty config name verified correct (config.ghostty on 1.2.3+) — no change
- [x] Rebuild (config applied; backup configuration.nix.bak-20260925-150604)
- [x] Extension installed + enabled in dconf; needs re-login to load
- [x] Pin VS Code in the dock (favorite-apps)
- [x] Icons resolve: vscode (pixmaps, GTK4 searches it) + ghostty (hicolor)
- [x] Clipboard plumbing verified: image/png on Wayland bridges to X11, 46837 B round-trip
- [x] Diagnose image paste: root cause = nix-ld lacks `libxcb`; curl-installed opencode can't dlopen the X11 clipboard backend
- [x] Verify fix locally: `LD_LIBRARY_PATH=<libxcb>/lib opencode` + image → `[Image 1]`; text `Ctrl+V` also inserts
- [x] configuration.nix: expose `libxcb` via nix-ld — delivered by epic 05 Layer 1 (single rebuild)
- [x] Rebuild (epic 05, exit 0); `libxcb.so.1` confirmed in `/run/current-system/sw/share/nix-ld/lib`
- [x] Image paste verified E2E: image on clipboard + `Ctrl+V` in opencode → `[Image 1]` (no manual LD_LIBRARY_PATH)
- [ ] File upstream: OpenTUI should fall back to X11 when ext/wlr-data-control absent (report skill)
- [ ] Commit
