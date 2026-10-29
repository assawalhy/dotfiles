# TODO — Copyous clipboard history (Gda + terminal paste)

Drafted 2026-10-20, revised and executed 2026-10-22 after the terminal-paste
regression report. See [PLAN.md](PLAN.md). The switch and the re-login are the
user's steps.

- [x] `nix/configuration.nix`: add the `libgda6` override (drop the libxml2 GIR
      include) (D2)
- [x] D3 dropped after build evidence: nixpkgs resolves `libgda6` in the final
      package set, so no `preInstall` rewiring is needed
- [x] `nix/configuration.nix`: add `gnomeExtensions.disable-extension-updates` to
      `environment.systemPackages` (D5)
- [x] `nix/configuration.nix`: add `disable-extension-updates@swsnr.de` to the
      `org/gnome/shell` `enabled-extensions` dconf default (D5)
- [x] `nix-instantiate --parse nix/configuration.nix` is clean
- [x] scratch system build succeeds:
      `/nix/store/8bx7kbamcp2jfvyxbsxix7ry77q36m2d-nixos-system-nixos-26.05.10402.1e8bc658fc98`,
      closure carries `libgda-6.0.0` at `2jhv5b2w...`, copyous at
      `jh1n4vlki2...` and `disable-extension-updates-10` at `jh814arms...`
- [x] the new copyous injects the patched libgda path, and the patched
      `Gda-6.0.typelib` lists only Gio, GLib and GObject
- [x] runtime A/B in gjs: `imports.gi.Gda` succeeds with the patched typelib and
      throws with the unpatched one
- [x] delete `~/.local/share/gnome-shell/extensions/copyous@boerdereinar.dev`
      (v11 / 2.1.1) and
      `~/.local/share/gnome-shell/extension-updates/copyous@boerdereinar.dev`
      (v12 / 2.1.2) (D1). Both directories are now empty, and
      `~/.local/share/copyous@boerdereinar.dev/clipboard.db` is untouched
- [ ] user: `nix/update-nixos.sh switch`
- [ ] user: log out and back in (a session restart is the only reload: the shell
      caches the deleted path, `ReloadExtension` is unimplemented on both D-Bus
      interfaces and `Eval` is refused)
- [ ] after the re-login: `gnome-extensions info copyous@boerdereinar.dev` shows
      the store copy, `State: ENABLED`, and the journal shows no
      `Failed to load Gda`
- [ ] copy a string and confirm the extension sees it and `clipboard.db` grows
- [ ] verify terminal auto-paste inserts the copied text, not the primary
      selection (user check in WezTerm)
- [ ] confirm the Extensions app stops offering copyous 2.1.x updates
      (`disable-extension-updates@swsnr.de` enabled)
- [ ] report the nixpkgs libgda typelib bug upstream (follow-up)
- [ ] re-check copyous #168 / #169 before any future nixpkgs copyous bump
      (follow-up)
