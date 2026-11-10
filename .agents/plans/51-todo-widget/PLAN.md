# Plan: Todo Widget GNOME extension

## Goal
Install Hamza-Djellal/todo-widget as a declarative NixOS system extension on
GNOME 50.4, enabled, reading `~/todo.txt`.

## Findings (verified)
- Shell 50.4, NixOS 26.05. UUID `todoWidget@Hamza-Djellal.github.com`,
  metadata declares 45–50, version 4 (upstream v1.3.0, HEAD `0d36c73`).
- Not on extensions.gnome.org (EGO's only todo extension stops at shell 47),
  so nixpkgs has no `gnomeExtensions.todo-widget`; the package must be ours.
- The repo commits its built `extension.zip` in the same commit as `src/`
  (zip metadata == repo metadata): metadata.json, extension.js, prefs.js,
  stylesheet.css, schema XML. Verified: a local `stdenvNoCC` build unpacks it
  and compiles the schema offline.
- The extension creates `~/todo.txt` and its parent dirs when missing;
  `todo-file-path` default `~/todo.txt`, `~` expanded via GLib.
- Widget is added to `Main.layoutManager._backgroundGroup` (desktop layer) at
  5%/88% of the primary monitor; draggable, with a position lock.
- Upstream has two unanswered "widget not responding" reports (Ubuntu 24.04
  GNOME 46, Ubuntu 26.04, Aug 2026). Ubuntu ships DING; this box runs DING too.

## Decisions
- D1 Package the committed `extension.zip` at rev `0d36c73` with
  `fetchFromGitHub` in `nix/todo-widget.nix`, built `stdenvNoCC`.
  Rejected: building TS from source (npmDepsHash, ~300 MB of @girs dev deps,
  tsc + prettier for the same output); `install.sh` into `~/.local/share`
  (non-declarative, diverges from every other extension here).
- D2 `dontBuild = true` so the repo Makefile's default `install` target
  (`npm run build`) never runs; installPhase just unzips and compiles schemas.
- D3 `environment.systemPackages` + `enabled-extensions` entry in the dconf
  profile, then `dconf reset /org/gnome/shell/enabled-extensions` (user DB
  shadows the profile default).
- D4 Upstream defaults only (dark, bottom-left, `~/todo.txt`, cross out
  completed); no dconf presets.
- D5 If the live test shows dead controls (the DING reports), add a guarded
  postInstall patch raising the widget over the desktop actor, pip-on-top
  style. Not before the evidence.

## Milestones
1. `nix/todo-widget.nix` + `let` binding + systemPackages + enabled-extensions.
2. Standalone `nix-build` of the package (schema compiles).
3. `nix/update-nixos.sh switch`.
4. `dconf reset`, `gnome-extensions enable`, `gnome-extensions info` ACTIVE.
5. Live check: widget visible, add/complete a task, no `[TodoWidget]` journal
   errors.
6. Commit.

## Risks
- Desktop-layer conflict with DING (two open upstream reports of dead
  controls). Fallback D5; if that fails, removal is one line.
- Not on EGO: no auto-updates, pinned to v1.3.0 / `0d36c73`.
- `_backgroundGroup` is private Shell API; a Shell bump can break it.
- Wayland cannot restart the Shell: a failed enable needs a re-login.
