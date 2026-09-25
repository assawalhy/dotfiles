# TODO

- [x] Confirm the 11 GB video is expendable (user: "you can remove the video")
- [x] configuration.nix: prefer ntfs-3g via services.udisks2.settings (mount_options.conf)
- [x] configuration.nix + setup/packages.list: add ntfs3g
- [x] Wedge cleared (0 current D-state, udisksd responsive)
- [x] Capacity check (last-4MiB wrap test: no wrap)
- [x] Format stick NTFS (mkntfs, label USB) + consistency check
- [x] sudo nixos-rebuild switch (applied in place with GUI sudo prompt)
- [x] Restart udisks2; mount verifies fuse.ntfs-3g (fuseblk, mount.ntfs, uid=1000)
- [x] Round-trip: unmount/remount + write test OK
- [ ] Commit (repo has unrelated staged work — commit only these 2 files)
