# Plan: GNOME desktop icons + image paste in opencode/Ghostty

## Goal
1. GNOME shows VS Code / Ghostty where the user expects (desktop background,
   app grid, dock).
2. Pasting an image into opencode's TUI under Ghostty works.

## Findings (verified)
- **Desktop icons:** GNOME Shell 50.4; `org.gnome.shell enabled-extensions` is empty
  and no shell extensions are installed. **GNOME 42+ has no desktop icons by
  default** — needs Desktop Icons NG (DING). Both apps' `.desktop` + icons exist
  (vscode → share/pixmaps/vscode.png; ghostty → hicolor png), so the app grid is
  fine; the background is the gap. Dock favorites already include ghostty.
- **Ghostty config:** `~/.config/ghostty/config.ghostty` is the **correct** name for
  Ghostty 1.2.3+ (docs). No change needed.
- **Image paste:** opencode reads the clipboard itself (native XCB/Wayland,
  preferred `image/png,text/plain`); `prompt.paste` = `ctrl+v`, which Ghostty does
  not bind, so the key reaches opencode. `wl-clipboard` is in `packages.list` but
  missing from `configuration.nix`.
- **Image paste root cause (verified):** opencode is the **curl-installed** Bun
  binary (`~/.opencode/bin`), i.e. a *foreign* binary. On NixOS it runs through
  nix-ld (`/lib64/ld-linux-x86-64.so.2` → nix-ld;
  `NIX_LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib`). OpenTUI's
  native host clipboard **dlopens** `libwayland-client.so.0` / `libxcb.so.1` at
  runtime; nix-ld's dir contains neither → the clipboard service can't be
  created → `Ctrl+V` reads nothing (text *and* image). Literal typing and
  Ghostty's bracketed paste (`Ctrl+Shift+V`) still work.
- **GNOME adds a second failure:** Mutter implements neither `ext-data-control`
  nor `wlr-data-control`, so even with `libwayland-client` loadable, OpenTUI's
  Wayland backend fails and does **not** fall back to X11. Verified:
  `LD_LIBRARY_PATH=<wayland>/lib` → still no paste.
- **Fix verified:** exposing only `libxcb` makes OpenTUI select the X11/XWayland
  backend and read the clipboard — `LD_LIBRARY_PATH=<libxcb>/lib opencode`, image
  on clipboard → TUI shows `[Image 1]`; text clipboard → `Ctrl+V` inserts it.
  Leaving Wayland's lib unavailable is deliberate: it keeps OpenTUI off the
  broken Wayland path.
- **Why codex works:** it is the nixpkgs build, so its loader/RPATH resolves its
  clipboard stack (`arboard`/`wl-clipboard-rs`); no runtime dlopen gap.

## Decisions
- D1 Desktop icons via `pkgs.gnomeExtensions.desktop-icons-ng-ding`
  (uuid `ding@rastersoft.com`; attr used in the NixOS test suite).
- D2 Enable via the existing `programs.dconf.profiles.user.databases`
  (`org/gnome/shell.enabled-extensions`), matching the input-sources entry.
  Rejected: `favoriteAppsOverride` (marked `internal = true`).
- D3 Add `wl-clipboard` + `mousepad` to `configuration.nix` to re-sync with
  `packages.list`.
- D4 Image paste: build first (wl-clipboard), then diagnose with a real image in
  the clipboard; fix or file upstream.
- **D5 Image-paste fix:** add `libxcb` to `programs.nix-ld.libraries` in
  `configuration.nix` (`with pkgs; [ libxcb ]`). Declarative, survives opencode
  updates, no wrapper, no `WAYLAND_DISPLAY` hack. **Deliberately exclude
  `wayland`** so OpenTUI stays on the X11 backend (GNOME lacks data-control).
  Rejected — wrapper with hardcoded store path (breaks on nixpkgs bumps);
  global `LD_LIBRARY_PATH` in `.zshrc` (system-wide, discouraged on NixOS);
  unsetting `WAYLAND_DISPLAY` (works, broader side effects); nixpkgs `opencode`
  (v1.18.31 — a V1 downgrade from the installed V2).

## Milestones
1. `configuration.nix`: DING + dconf enabled-extensions; wl-clipboard/mousepad.
2. Rebuild + re-login.
3. Verify extension enabled + icons render; pin VS Code in the dock if wanted.
4. ~~Clipboard diagnostic~~ → root cause found (nix-ld lacks `libxcb`).
5. `configuration.nix`: `programs.nix-ld.libraries = with pkgs; [ libxcb ]`.
6. Rebuild; verify `libxcb.so.1` appears in the nix-ld library dir.
7. Verify real paste: image on clipboard + `Ctrl+V` in opencode → `[Image 1]`.
8. File upstream (OpenTUI should fall back to X11 when data-control is absent).

## Risks
- Rebuild needs sudo (drive the zenity askpass prompt).
- DING may need a re-login / Shell reload to render.
- Image paste is a NixOS packaging gap, not a Ghostty/open-config issue: the
  curl-installed opencode must have `libxcb` reachable by nix-ld. Adding
  `wayland` to nix-ld would re-select the broken Wayland backend — do not.
- Upstream nixpkgs PR #48928 (merged 2026-09-14) fixes only the *nix-packaged*
  build and only Wayland; it does not cover the curl install / nix-ld path.
