# TODO — NixOS config under `nix/` + deploy script

- [x] move `configuration.nix` → `nix/configuration.nix` (plain `mv`; user's
      uncommitted edits stay off the index)
- [x] fix relative refs: `./copyous-terminal-paste/terminal-paste.patch`; updated
      the overlay comment
- [x] add `nix/update-nixos.sh` (rsync mirror + excludes + backup +
      `nixos-rebuild`, `cp` fallback, `-n`, `-h`)
- [x] add `rsync` to `environment.systemPackages`
- [x] update AGENTS.md (config path + script)
- [x] validate: temp-dir build (`nixos-rebuild build` → exit 0), extension
      byte-identical to the reference tree
- [x] exercise `nix/update-nixos.sh -n` (dry-run, no writes)
- [x] deploy: `nix/update-nixos.sh` on the host (sudo) — switched to
      `3dxlrq9ykx6jlnkkzd3ibaq5ylyyk53l`
- [ ] re-login + verify (epic 23)
- [x] commit — `3bddf16`
