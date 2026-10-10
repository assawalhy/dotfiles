# TODO — Add swap to stop OOM kills

- [x] add `zramSwap` block to `nix/configuration.nix`
- [x] add `/var/swapfile` (16 GiB) to `swapDevices` in `nix/configuration.nix`
- [x] add `boot.kernel.sysctl."vm.swappiness" = 100`
- [x] validate: `nixos-rebuild build` offline (config evaluates, no sudo)
- [x] deploy: `nix/update-nixos.sh` (sudo → switch)
- [x] verify: `swapon --show` (zram0 prio 5 + swapfile), `zramctl`,
      `free -h`, `vm.swappiness=100`, oomd log no longer "No swap"
- [x] commit (`nix:` scope) — `ab9e236`
