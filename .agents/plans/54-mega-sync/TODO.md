# TODO: MEGAsync from the official deb

- [x] Write `nix/megasync/default.nix` (dpkg extract, autoPatchelf, wrapQtApps, bundled ffmpeg).
- [x] Write `nix/megasync/update.sh` and run it once (expect "already 6.7.0-1.1").
- [x] `nix/configuration.nix`: `(callPackage ./megasync { })` replaces the deferred comment.
- [x] `nix/configuration.nix`: add `gnomeExtensions.appindicator` and enable its UUID.
- [x] Build: `nix/update-nixos.sh build`.
- [x] Switch: `nix/update-nixos.sh switch`.
- [ ] Log out and back in, then launch `megasync`, log in, confirm the tray icon and a synced folder.
