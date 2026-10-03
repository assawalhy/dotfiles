# TODO — GNOME top-bar stats (Astra Monitor)

- [x] epic files created (this dir)
- [x] configuration.nix: add gnomeExtensions.astra-monitor
- [x] configuration.nix: enabled-extensions += monitor@astraext.github.io
- [x] configuration.nix: astra-monitor dconf presets (RAM % + coretemp sensor)
- [x] parse check configuration.nix
- [x] backup + copy configuration.nix to /etc/nixos
- [x] nixos-rebuild switch (zenity askpass) exit 0
- [x] extension dir exists in /run/current-system sw
- [x] dconf reset /org/gnome/shell/enabled-extensions
- [x] presets verified in dconf (4 astra keys + 3 enabled-extensions)
- [x] load attempt: live enable failed — Shell session predates the package; re-login required
- [ ] re-login → monitor@astraext.github.io ENABLED/ACTIVE
- [ ] verify: RAM % + temperature visible in top bar; no astra journal errors
- [x] commit (done first, to keep the copyous diff separate)
