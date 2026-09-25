# TODO

- [x] configuration.nix: `programs.nix-ld.libraries = with pkgs; [ libxcb glib libsecret alsa-lib libpulseaudio ]`
- [x] configuration.nix: `services.envfs.enable = true`
- [x] `nix-instantiate --parse configuration.nix` (repo + /etc/nixos)
- [x] apply config to `/etc/nixos/configuration.nix` (backup bak-20260925-231149; lazygit hunk excluded — other epic)
- [x] rebuild (`nixos-rebuild switch`, sudo/zenity askpass) — exit 0
- [x] verify `libxcb/glib/libsecret/alsa/pulse` in `/run/current-system/sw/share/nix-ld/lib` (wayland absent)
- [x] verify envfs: `/usr/bin/env` + `/bin/bash` resolve (`fuse envfs` on /usr/bin + /bin; `bash -c` ok)
- [x] verify opencode image paste with no manual `LD_LIBRARY_PATH` → `[Image 1]`
- [x] update epic 04 (D5 delivered via this epic)
- [ ] commit — deferred (working tree holds other epics' staged changes; avoid a mixed commit)
