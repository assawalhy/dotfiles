# TODO: Claude Desktop and Orca

- [x] Add `nix/claude-desktop/default.nix` (adapted from poeck/claude-desktop-nix-flake, version `2.42304.0`, amd64 + arm64 hashes from the apt `Packages` index)
- [x] Add `nix/claude-desktop/update.sh` (bumps version + hashes from the apt index)
- [x] Add the package to `environment.systemPackages` in `nix/configuration.nix`
- [x] Add `programs.appimage = { enable = true; binfmt = true; };`
- [x] `nix/update-nixos.sh build` succeeds (via ajq)
- [x] Download `orca-linux.AppImage` v1.4.229 to `~/Applications/`, `chmod +x`, extract the icon
- [x] Add `common/.local/share/applications/orca-ide.desktop` and run `link-files --fix`
- [x] `nix/update-nixos.sh` switch (needs sudo; user runs it)
- [x] Verify: `claude-desktop` opens and signs in; Orca opens from the app grid
