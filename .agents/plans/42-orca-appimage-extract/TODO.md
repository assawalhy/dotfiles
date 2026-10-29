# TODO: Orca AppImage extraction under binfmt

- [x] Add `nix/appimage-binfmt.sh` (extract, offset, otherwise delegate to appimage-run)
- [x] `nix/configuration.nix`: `binfmt = false`, add the two `boot.binfmt.registrations`, define the wrapper in the top-level `let`
- [x] `bash -n` and direct run of the wrapper: extract into a temp dir, check `squashfs-root/resources/bin/orca-ide`, check `--appimage-offset` prints 944632
- [x] Full system evaluation and build of the toplevel from the repo tree (ajq), since `nix/update-nixos.sh build` also syncs to `/etc/nixos`
- [ ] User: `nix/update-nixos.sh switch`
- [ ] Verify binfmt entry points at the wrapper and Orca launches from the app grid
- [ ] Register the CLI in Orca after a full restart, confirm `~/.local/bin/orca` and `orca --version`
- [x] Prune the unused `~/.cache/appimage-run` generations (3 removed, 1.85 GB); `033e947` kept while its pre-update daemon still runs
