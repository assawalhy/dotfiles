# Plan — ranger image previews in Ghostty + devicons linemode

## Goal
ranger shows image previews inside Ghostty, and `default_linemode devicons`
loads instead of erroring with "Invalid linemode: devicons".

## Findings (probed in a real Ghostty 1.3.1 surface)
- Ghostty replies `EINVAL: invalid data` to ranger's kitty-graphics query
  (ranger sends `S=3`); open upstream ranger#3203. The same query **without**
  `S` returns `OK`.
- Ghostty accepts direct transmission (`t=d`) and simple-file (`t=f`), but
  rejects ranger's preferred temp-file medium (`t=t` → "temporary file not
  named correctly"). ranger's `stream=True` (direct, RGBA `t=d`) draw → `OK`.
- Conclusion: **no config-only fix exists.** ranger aborts on the EINVAL reply
  before drawing.
- `common/.config/ranger/plugins/ranger_devicons` is a gitlink with no
  `.gitmodules` → never checked out. `setup/steps/30-ranger-devicons.sh` clones
  it but never ran. The upstream plugin imports cleanly under ranger 1.9.4.

## Decisions
- Images: patch ranger via `nixpkgs.overlays` — treat an `EINVAL` query reply
  like `EBADF`, so ranger uses direct (`t=d`) streaming; set
  `preview_images_method kitty`. One `substituteInPlace`, native rendering, no
  daemon. *(Rejected: `ueberzugpp` — extra daemon + config and GNOME-Wayland
  quirks; rejected: ranger plugin monkeypatch — fragile private-API patch;
  rejected: wait for upstream — ranger#3203 open, milestone v1.9.6.)*
- Devicons: drop the broken gitlink; keep `link-ignore.txt` + step 30; run the
  clone now. Repo policy installs third-party artifacts fresh from source and
  does not vendor them. *(Rejected: vendoring the ~420-line icon map.)*
- `common/.config/ranger/rc.conf`: restore `set preview_images_method kitty`.

## Milestones
1. rc.conf: image method.
2. configuration.nix: ranger overlay.
3. gitlink removal + devicons clone.
4. Sync to `/etc/nixos` + `nixos-rebuild switch`; verify.

## Risks
- Rebuild needs sudo. The ranger source is already in the store, so it is a
  local rebuild, not a fetch.
- `substituteInPlace --replace-fail` makes a future ranger bump fail the build
  loudly if that line moves — self-documenting, but the overlay must be revisited.
- Drop the overlay once ranger#3203 is fixed upstream.
