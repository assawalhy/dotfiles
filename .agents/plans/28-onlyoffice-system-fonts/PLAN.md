# 28 — ONLYOFFICE Desktop sees the system fonts

## Goal
ONLYOFFICE Desktop's font picker and substitution see the system fonts, not
just the 16 faces bundled in the app.

## Root cause (verified)
- The app builds its font list by scanning `~/.local/share/fonts` (and its own
  bundled dir), recursively, **skipping symlinks** — both file and directory.
- On NixOS `/run/current-system/sw/share/fonts` is a **symlink farm**: 373 font
  entries, 0 real files, every one a link into `/nix/store`.
- So the app indexes nothing system-wide. Proof: copying `NotoSansArabic.ttf`,
  `NotoNaskhArabicUI.ttf`, `DejaVuSans.ttf` as real files into
  `~/.local/share/fonts` and clearing its cache took `fonts.log` from 16 → 25
  entries and added the families to `AllFonts.js`. A symlinked file, a symlinked
  directory, and a top-level symlinked `~/.local/share/fonts` were all ignored;
  a real subdirectory was recursed.

## Approach
A `systemd.user.services.onlyoffice-system-fonts` oneshot at login:
- `rsync -aL --delete --exclude NerdFonts /run/current-system/sw/share/fonts/`
  → `~/.local/share/fonts/system/` — dereferenced, so real files.
- `rm -rf` the app's generated font cache so it reindexes on next start.

## Decisions
- **Real copies, not symlinks.** The scanner ignores symlinks; hard links also
  fail (`EXDEV` across btrfs subvolumes). Copies are the only option.
- **Exclude `NerdFonts`.** 269 MB of terminal-only fonts with no document use;
  the mirror is ~127 MB instead of ~396 MB.
- **User service, not a package override.** Fixes it for the app without a
  3 GB `onlyoffice-desktopeditors` rebuild.
- **Keeps epic 27's `prgname` rule.** The mirror puts DejaVu/Noto in the app's
  list; the rule is what routes `Arial` to DejaVu Sans for Arabic.
- **Adds `dejavu_fonts` to `fonts.packages`.** DejaVu was only a transitive
  dependency (present to fontconfig, absent from
  `/run/current-system/sw/share/fonts`), so the mirror missed it and epic 27's
  `Arial → DejaVu Sans` rule would have had no face to land on.

## Milestones
1. Add the user service to `configuration.nix`; parse check.
2. Rebuild + switch; start the service; verify the mirror and the app's list.
3. Commit.

## Risks
- ~127 MB duplicated under the home dir; rsync refreshes it at login.
- Fontconfig also scans the mirror (duplicate families with the store fonts) —
  harmless, same faces.
- The app cache is dropped at login; thumbnails regenerate once on next start.
