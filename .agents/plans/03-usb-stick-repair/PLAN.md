# Plan: USB stick — repair + stop the ntfs wedge loop

## Goal
Make the Kingston stick (14.5G) usable again and break the recurring loop:
dirty NTFS -> udisksd wedged -> can't open/unmount/eject -> reboot.

## Approach
1. Stop using the in-kernel `ntfs3` driver for removable NTFS: point udisks2 at
   `ntfs-3g` (FUSE) via `/etc/udisks2/mount_options.conf`.
2. Verify the drive's real capacity before trusting it — its USB ID is a
   counterfeit signature.
3. Format fresh NTFS, mount through udisks, confirm it lands on `fuse.ntfs-3g`
   and survives a dirty-volume + clean-unmount round trip.

## Decisions
- D1 Filesystem stays NTFS; driver switches `ntfs3` -> `ntfs-3g`.
  Rationale: `ntfs3` hung the kernel twice (`ntfs3_kill_sb` D-state) and refuses
  dirty volumes; `ntfs-3g` auto-recovers dirty NTFS and is a killable userspace
  process. Rejected: keep `ntfs3` (recurring hangs); exFAT (loses NTFS — but it
  is the alternative if cross-platform read-write matters more than NTFS).
- D2 Config via `environment.etc."udisks2/mount_options.conf"` with
  `ntfs_drivers=ntfs`. Rationale: udisks2's supported knob, found in the
  package's own `mount_options.conf.example`; NixOS has no dedicated option.
  Rejected: manual `mount -t ntfs-3g` (bypasses udisks, breaks the GUI).
- D3 Test capacity/authenticity before formatting. Rationale: idVendor `058f`
  (Alcor) claiming "Kingston DataTraveler 2.0" — genuine Kingston is `0951`;
  fake-capacity drives hang USB storage exactly like this past real capacity.
- D4 Install `ntfs3g` system-wide (+ mirror in `setup/packages.list`) to get
  `mkntfs`/`ntfsfix`/`ntfs-3g` on PATH. udisks already has it as a private dep.

## Milestones
1. Repo: `configuration.nix` + `setup/packages.list`.
2. Reboot — clears the wedged `usb-storage` (unkillable without it).
3. `sudo nixos-rebuild switch`.
4. Capacity test -> format NTFS -> mount via udisks -> verify `fuse.ntfs-3g`.
5. Dirty-volume + clean-unmount round-trip test.

## Risks
- FORMAT ERASES the 11 GB video currently on the stick — back it up first.
- Drive may be counterfeit/failing; if the capacity test fails, formatting is
  pointless -> replace it.
- It hangs off two cascaded USB hubs; try a direct root port.
- Reboot and rebuild need sudo (you run those; I have no password here).
