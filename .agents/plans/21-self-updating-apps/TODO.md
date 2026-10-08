# TODO — self-updating apps (opencode-desktop, VS Code)

## zapfast — uninstall  ✅ DONE

- [x] `nix profile remove nix/zapfast-uri` (removed 1, kept 3)
- [x] rm `~/.local/share/applications/zapfast.desktop` (dangling profile symlink)
- [x] drop the `x-scheme-handler/whatsapp` + `x-scheme-handler/wa` entries from
      `~/.config/mimeapps.list` (backed up to `mimeapps.list.bak-<ts>`);
      `gio mime` now reports "No default applications" for both
- [x] `nix/zapfast-uri/` flake + `uri-handler.patch` **deleted** (2026-10-08) —
      zapfast is not mature enough to carry a local patch flake. Epic 19 is
      marked DROPPED but kept as the record of PR
      <https://github.com/crmne/zapfast/pull/426> (still open upstream). The
      `/etc/nixos/zapfast-uri/` mirror copy is left for the next
      `update-nixos.sh` to remove via `rsync --delete`.

## opencode-desktop — keep the self-updating AppImage  ✅ DONE

- [x] `setup/steps/71-opencode-desktop.sh` (`# os: any`): Linux → AppImage in
      `~/Applications` + `~/.local/bin` launcher + `.desktop` (absolute `Exec`);
      macOS → `brew install --cask opencode-desktop`. Version resolved from the
      `opencode.ai/download/stable/…` redirect, so never pinned stale.
- [x] launcher prefers `appimage-run` (needed on NixOS) and falls back to
      running the AppImage directly elsewhere; both keep self-update working
- [x] ran it here: reports 2.0.24, leaves the existing AppImage alone (it
      self-updates), regenerates launcher + entry → idempotent
- [x] flake approach **dropped** (D1): `appimageTools.wrapType2` would put it in
      the read-only store and break the updater

## VS Code — BLOCKED on a decision, see PLAN Findings

Upstream evidence (release/1.141, `updateService.linux.ts`):
**VS Code on Linux cannot self-update.** `doDownloadUpdate` only calls
`openExternal(downloadUrl)` — it opens the download page in a browser and
returns to `Idle(UpdateType.Archive)`. deb/rpm get updated by the package
manager; the tarball gets nothing.

- [x] installed the official 1.141.0 tarball to `~/.local/opt/vscode` to test
      (sha256 `d77d588f…` verified against the update API)
- [x] confirmed the tarball keeps `updateUrl` — but that only buys *notifications*
- [x] confirmed it does **not** run here as-is: `libgtk-3.so.0` missing
      (nix-ld alone is not enough; it needs an FHS wrapper)
- [x] **removed** the half-install; nothing broken left behind
- [ ] **decide**: (A) `vscode` from the existing `unstable` pin — current, no
      FHS hack, updates on rebuild; or (B) flatpak `com.visualstudio.code` —
      true auto-update, but adds flatpak as a second updater
