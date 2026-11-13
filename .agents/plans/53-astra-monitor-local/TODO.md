# TODO — Astra Monitor built and developed locally

See [PLAN.md](PLAN.md).

- [x] Research: version gap (nixpkgs release 39 vs upstream 43), missing GTop on
      NixOS, per-tick lsblk spawns, NVIDIA/sensors/menu paths
- [x] `nix/astra-monitor/package.nix`: pinned upstream source, `tsc --noCheck`,
      schemas, locales, GTop typelib path (D1–D3)
- [x] Patch 0001: storage usage via Gio statfs, cached lsblk list, `_` in
      device paths (D4); type-checks against `@girs`, gjs-verified numbers
      match GTop
- [x] `nix/astra-monitor/dev.sh` (init/check/build/nested/export/bench/log),
      init → build → export round-trip tested, shellcheck clean (D5)
- [x] Swap `gnomeExtensions.astra-monitor` for the local package in
      `nix/configuration.nix`; full NixOS eval (stub hardware file) lists it
- [ ] Baseline before deploying: `nix/astra-monitor/dev.sh bench 60`
- [ ] Deploy: `nix/update-nixos.sh`, then re-login
- [ ] `dev.sh bench 60` again and record both results here
- [ ] Check GTop is detected (Preferences → Utility) and the storage header works
- [ ] `nix/astra-monitor/dev.sh init` and try `dev.sh nested` once
- [ ] Turn on the Intel UHD 620 in Preferences → GPU → General; revisit epic 25 D3
- [ ] Optional: offer patch 0001 upstream
- [ ] Optional: dGPU runtime-suspend guard for the nvidia-smi task (see PLAN)
