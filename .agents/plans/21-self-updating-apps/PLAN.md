# PLAN — self-updating apps (opencode-desktop, VS Code)

## Goal

Apps whose upstream **auto-updates** must live in user-writable space, not in
`/nix/store`. Two currently don't:

- **opencode-desktop** — already installed the right way (AppImage in
  `~/Applications`, self-updates: it went 2.0.22 → 2.0.24 on its own), but the
  launcher/entry/icon are hand-made and untracked, so a fresh machine loses it.
- **VS Code** — `vscode.fhs` from the 26.05 channel is **1.119.0**, and nixpkgs
  actively deletes `updateUrl` from `product.json`
  (`vscode/generic.nix:387`), so it can never update. Current stable is
  **1.141.0**.

Also: **uninstall zapfast** (done — profile, desktop link, `whatsapp:`/`wa:`
handlers all removed).

## Decisions (revised)

- **D1 Superseded: no flake for opencode-desktop.** The previous plan packaged
  it with `appimageTools.wrapType2`, which puts it in `/nix/store` — read-only,
  so the app's own updater breaks. You asked to keep auto-update, so the
  AppImage stays in `~/Applications` and the profile is left alone.
- **D2 Source = the opencode.ai CDN**, version resolved at run time from
  `https://opencode.ai/download/stable/<target>` → `…/files/bin/<ver>/…`.
  Verified: the local file is byte-identical to `2.0.24` on that CDN
  (sha256 `af937c13…`). The GitHub release channel is a *different* app
  (desktop 1.18.34).
- **D3 Reproducibility comes from a `setup/steps/` script**, not the flake:
  `setup/` is never linked, so it can't trip `link-files`' capture scan (adding
  `.local/bin/opencode-desktop` to the repo would make `--refresh` try to sweep
  the other 18 installer binaries into the repo).
- **D4 VS Code = the official Microsoft tarball** into a user-writable
  `~/.local/opt/vscode/`, launcher in `~/.local/bin`, own `.desktop`; remove
  `vscode.fhs` from `nix/configuration.nix`. Keeps `updateUrl` (so the built-in
  updater works) and is current. Rejected: `vscode` from nixpkgs-unstable —
  newer, but still no updater.
- **D5 `check:` markers test the user-space install**, not `command -v`, so the
  steps don't think they're done because some other `code` is on `PATH`.
- **D6 Keep `environment.localBinInPath = true`** — now load-bearing: it is what
  puts both `~/.local/bin` launchers on the GNOME session PATH.

## Shape

```
setup/steps/71-opencode-desktop.sh   # os: any — Linux AppImage / macOS cask
setup/steps/72-vscode.sh             # os: any — Linux tarball / macOS cask
nix/configuration.nix                # - vscode.fhs
```

## Milestones

1. `setup/steps/71-opencode-desktop.sh`, then run it here (idempotent).
2. `setup/steps/72-vscode.sh`, install here, verify `code --version` = 1.141.0.
3. `nix/configuration.nix`: drop `vscode.fhs`; deploy + rebuild.
4. Verify both under the **session** PATH, and that `product.json` still has
   `updateUrl` (i.e. VS Code can update).
5. Docs + commit.

## Risks

- **VS Code's updater on the archive build.** The tarball keeps `updateUrl`,
  but Linux archive self-update is the least-tested path. Verify by inspecting
  `product.json` and the update setting; if it can't self-apply, the step is the
  update path (re-run it) and that must be stated plainly, not glossed.
- Removing `vscode.fhs` takes `code` off the system PATH; both launchers then
  depend on `localBinInPath` + a re-login.
- The opencode AppImage's self-update writes to `~/Applications` — fine there,
  which is precisely why it must not move into the store.
- zapfast's `nix/zapfast-uri/` flake and epic 19 remain in the repo; only the
  install was removed.
