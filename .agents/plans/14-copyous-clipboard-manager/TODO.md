# TODO — Copyous clipboard manager (replace CopyQ)

- [x] epic files created (this dir)
- [x] configuration.nix: - copyq, + gnomeExtensions.copyous
- [x] configuration.nix: enabled-extensions += copyous@boerdereinar.dev
- [x] setup/packages.list: - copyq
- [x] delete ~/.config/autostart/com.github.hluk.copyq.desktop
- [x] parse check configuration.nix
- [x] backup + copy configuration.nix to /etc/nixos
- [x] nixos-rebuild switch (zenity askpass) exit 0
- [x] copyous dir exists in /run/current-system sw
- [x] dconf reset /org/gnome/shell/enabled-extensions
- [ ] re-login (shared with epic 13) → copyous EXTENSION ACTIVE
- [ ] verify: Super+Shift+V opens dialog, deps OK, no journal errors
- [x] commit
