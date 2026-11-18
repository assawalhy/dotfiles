# Plan: MEGAsync on NixOS from the official .deb

## Goal

MEGA desktop sync client (6.7.0) installed as a system package on this GNOME 50 /
Wayland box, with a reachable UI and a repeatable update path.

## Findings

- `pkgs.megasync` in the 26.05 channel is 6.5.1.0, `src = fetchgit github.com/meganz/MEGAsync.git`.
  Unfree, so cache.nixos.org never built it; the git fetch died mid-pack on 2026-09-24.
  That is why `nix/configuration.nix:613` is commented out.
- MEGA publishes `megasync_6.7.0-1.1_amd64.deb` (54.8 MB) for xUbuntu 24.04 at
  `https://mega.nz/linux/repo/xUbuntu_24.04/amd64/`, new enough to beat the channel.
  Control: Qt5 app, deps `libqt5{core,dbus,gui,network,qml,quick,quickwidgets,svg,widgets,x11extras}`
  plus the Qt Quick QML modules (dialogs, controls, controls2, graphicaleffects).
- Both binaries carry `RUNPATH=/opt/megasync/lib`, which holds MEGA's own ffmpeg 7.1
  (libavcodec.so.61, libavformat.so.61, libavutil.so.59, libswscale.so.8).
- Resources load from `$ORIGIN/../share/megasync/resources`, so `$out/bin` plus
  `$out/share/megasync/resources` is the layout the binary expects.
- `mega-desktop-app-gfxworker` is resolved next to the main binary; it needs only the
  ffmpeg libs.
- The binary contains an AppIndicator check (`gnome-extensions enable
  appindicatorsupport@rgcjonas.gmail.com`). GNOME here has no tray host: none of the
  enabled extensions provide one.
- `fs.inotify.max_user_watches` is already 524288, the deb's sysctl value. The deb's
  udev rule (`SUBSYSTEM=="block", ATTRS{idDevtype}=="partition"`) is a no-op skeleton.

## Approach

Package the deb the way `nix/claude-desktop` already does: `dpkg-deb` extract,
`autoPatchelfHook`, `wrapQtAppsHook`, plus a `update.sh` that rewrites version and hash.
Keep MEGA's bundled ffmpeg. Add the AppIndicator extension for the tray.

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Package the official deb, not `pkgs.megasync` | No git clone, no source build, 6.7.0 instead of 6.5.1.0. Rejected: `pkgs.megasync` (fetch blocked, unfree means no cache, long compile), Flatpak (`nz.mega.MEGAsync` is not on Flathub; the appstream API returns `App not found`), AppImage (MEGA ships none). |
| D2 | Keep the bundled ffmpeg 7.1 from `/opt/megasync/lib` | Same ABI as `ffmpeg_7`, but MEGA's build carries the codecs its previews expect. Costs 19 MB. |
| D3 | Qt5 inputs + `wrapQtAppsHook`, `QT_QPA_PLATFORM=xcb` | The app is Qt5/X11; no qtwayland is provided, so XWayland is the deterministic path. `xdg-utils` on PATH to open folders. |
| D4 | Add `gnomeExtensions.appindicator` (v64) and enable its UUID | MEGAsync is a tray app and GNOME 50 has no tray host. |
| D5 | `nix/megasync/{default.nix,update.sh}` mirroring `nix/claude-desktop` | Same shape as the existing foreign-package precedent; `update.sh` reads the repo listing and rewrites version + hash. |
| D6 | Skip the deb's udev rule and sysctl | No-op rule; inotify value already set. |
| D7 | Add `StartupWMClass=megasync` to the desktop entry | Without it the dash does not associate the window with the icon, same problem noted for Obsidian. |

## Milestones

1. `nix/megasync/default.nix` with `dpkg`, `autoPatchelfHook`, `wrapQtAppsHook`.
2. `nix/megasync/update.sh`, run once (expect "already 6.7.0-1.1").
3. `nix/configuration.nix`: replace the deferred comment with `(callPackage ./megasync { })`,
   add `gnomeExtensions.appindicator`, enable `appindicatorsupport@rgcjonas.gmail.com`.
4. Build, switch, launch, verify login window and tray icon.
5. Log out and back in once: a system extension added by a switch is only
   scanned by GNOME Shell at startup, so the tray host does not exist before that.

## Risks

- MEGAsync's tray may be XEmbed (Qt5 `QSystemTrayIcon`), which has no host under XWayland.
  Then the icon stays invisible and the settings window is the way in. Fallback is the
  mock-tray extension; the app itself works either way.
- Qt5 under XWayland does not do fractional scaling, so the window can look soft at 125%.
- The repo path only has amd64 packages, so the derivation declares x86_64-linux only.
- Every version bump is manual (`update.sh` plus a switch); the in-app updater cannot
  install on NixOS.
- Rebuild writes to `/etc/nixos` and needs sudo.
