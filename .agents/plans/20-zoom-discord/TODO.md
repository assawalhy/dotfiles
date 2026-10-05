# TODO — Zoom + Discord on NixOS

- [x] 1. `configuration.nix`: add `programs.zoom-us.enable = true` (next to the
      other `programs.*` blocks, with a comment on why the module not the
      package)
- [x] 2. `configuration.nix`: `discord` in `environment.systemPackages` `## [gui]`
- [x] 3. parse clean (`nix-instantiate --parse`); eval: zoom 7.1.5.4332 enabled,
      discord 1.0.156 in systemPackages, `xdg.portal.enable` = true. Portal
      wiring verified on the **FHS rootfs** drv (`…zoom…-fhsenv-rootfs.drv`
      references `xdg-desktop-portal-gnome` + `-gtk`; the bare package's rootfs
      references none) — the module's rewrite lands in systemPackages, not in
      `config.programs.zoom-us.package`, so compare there.
- [x] 4. backup `/etc/nixos/configuration.nix.bak-20261006-021310` + copy repo
      file over; diff clean
- [x] 5. `sudo -A nixos-rebuild switch` (zenity askpass) → **Done**, new config
      `/nix/store/4qzd7b7aqch5h0n7vyjn1gan4faahgk6-nixos-system-nixos-26.05.10402.1e8bc658fc98`
- [x] 6. verify: `sw/bin/{zoom,zoom-us,discord}` all symlink into the new
      generation; `discord --version` → `Discord 1.0.156`; `Zoom.desktop` +
      `discord.desktop` in `sw/share/applications`. Zoom has no `--version`
      flag — it boots the FHS launcher (killed after confirming `Install dir
      is: /opt/zoom`); version read off the store path instead.
      Portal wiring confirmed live: the built rootfs
      `…-zoom-7.1.5.4332-fhsenv-rootfs` contains `usr/bin/xdg-desktop-portal`,
      `-gnome`, `-gtk`, `ibus-portal`, `xdg-document-portal`.
- [x] 7. commit `14f7e90` (`nixos: add zoom-us and discord`) — config + epic
      files only. The first attempt swept in the already-staged `nix/zapfast-uri/`
      from epic 19; reset and recommitted just my files, then re-staged
      zapfast to its original state.
