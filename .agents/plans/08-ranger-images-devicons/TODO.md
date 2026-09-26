# TODO — ranger image previews in Ghostty + devicons linemode

- [x] `common/.config/ranger/rc.conf`: `set preview_images_method kitty`
- [x] `configuration.nix`: `nixpkgs.overlays` patch — ranger's `_late_init`
      treats an `EINVAL` query reply like `EBADF` (direct `t=d` streaming)
- [x] `git rm --cached common/.config/ranger/plugins/ranger_devicons` (broken
      gitlink, no `.gitmodules`)
- [x] run `setup/steps/30-ranger-devicons.sh`; confirm
      `~/.config/ranger/plugins/ranger_devicons/__init__.py` and that
      `default_linemode devicons` no longer errors
- [x] copy `configuration.nix` to `/etc/nixos/` (backup old) + `nixos-rebuild switch`
- [x] verify: patched line present in the new ranger store path; devicons render;
      user confirms image previews in Ghostty

## Verification log
- Ghostty 1.3.1 probe (real surface): ranger query → `EINVAL`; without `S` →
  `OK`; `t=t` → `EINVAL`; direct RGBA `t=d` → `OK`
- devicons plugin imports and registers `devicons` in
  `FileSystemObject.linemode_dict` after clone
- `nixos-rebuild switch` rc=0; new ranger
  `qrjq4ydprx4l9bq9llkx4l8jd28l95gh` line 771:
  `elif b'EBADF' in resp or b'EINVAL' in resp:`
- patched `KittyImageDisplayer` in a real Ghostty surface:
  `late_init OK (stream=True)` → `draw OK`
