# Plan: Copyous clipboard manager (replace CopyQ)

## Goal
Replace CopyQ with Copyous (GNOME-native Wayland clipboard manager) and drop
copyq from both package sources.

## Findings (verified)
- GNOME Shell 50.4; Copyous uuid `copyous@boerdereinar.dev`; EGO v9 =
  upstream 2.0.1, declares shell 48–50.
- nixpkgs `extensionOverrides.nix` patches it to prepend Gda/GSound typelib
  paths from `buildInputs = [ libgda6 gsound ]` (nixpkgs PR #469919). Cached:
  verified `nix-build` fetches, no local build. No system package/env hacks.
- Repo copyq references: `configuration.nix` [gui], `setup/packages.list`.
- Stale autostart entry: `~/.config/autostart/com.github.hluk.copyq.desktop`.
  CopyQ data (`~/.config/copyq`, 84K) is left in place.

## Decisions
- D1 `pkgs.gnomeExtensions.copyous` (official override) — rejected manual
  GitHub-release packaging (same fix already in nixpkgs), Pano (predecessor).
- D2 Remove copyq from `configuration.nix` + `packages.list`; delete its
  autostart entry; keep `~/.config/copyq`.
- D3 No dconf presets; Copyous defaults (dialog on Super+Shift+V, prefs).

## Milestones
1. configuration.nix: - copyq, + gnomeExtensions.copyous, enabled-extensions
   += `copyous@boerdereinar.dev`.
2. setup/packages.list: - copyq; remove stale autostart entry.
3. Deploy /etc/nixos (timestamped backup) + nixos-rebuild switch.
4. dconf reset; re-login (shared with epic 13).
5. Verify: EXTENSION ACTIVE, deps OK, Super+Shift+V opens the dialog.
6. Commit.

## Risks
- Copyous is young (2.0.1); disable with one line if it misbehaves.
- Verification requires the same re-login epic 13 needs (Wayland).
- CopyQ history cannot be imported; kept on disk for a possible reinstall.
