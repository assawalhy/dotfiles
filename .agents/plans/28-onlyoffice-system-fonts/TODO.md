# TODO — epic 28

- [x] diagnose: app scans `~/.local/share/fonts`, skips symlinks; NixOS fonts are symlinks → 0 indexed
- [x] prove: real files there are indexed (16 → 25 entries), symlinks are not
- [x] `configuration.nix`: add `systemd.user.services.onlyoffice-system-fonts` mirror (exclude NerdFonts)
- [x] `nix-instantiate --parse nix/configuration.nix` OK
- [x] add `dejavu_fonts` to `fonts.packages` (DejaVu was only transitive; mirror needed it)
- [x] rebuild + switch via `nix/update-nixos.sh`
- [x] restart service; verify mirror (127 MB, real files) + ONLYOFFICE `fonts.log` 16 → 306, all epic-27 faces present
- [x] remove manual flat test copies (mirror supersedes them)
- [ ] commit
