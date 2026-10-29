# TODO — Astra Monitor "No GPU found" (GPU detection)

**NOT STARTED.** Updated 2026-10-17: the hardware table in PLAN.md was wrong
(this card is a Quadro T2000, not a P2000) and this epic now depends on epic
[38](../38-hybrid-gpu-offload/PLAN.md) for `nvidia-smi`.
See [PLAN.md](PLAN.md) and issue
[#27](https://github.com/assawalhy/dotfiles/issues/27).

- [ ] wait for epic 38 (hybrid GPU driver), so `nvidia-smi` exists
- [ ] add `pciutils` (+ `intel-gpu-tools`) to `environment.systemPackages` in
      `nix/configuration.nix` (D1)
- [ ] deploy: `nix/update-nixos.sh` (switch)
- [ ] re-login: the Shell memoises `lspciCached`, so a reload is required
- [ ] confirm the GPU section lists the NVIDIA T2000 and the Intel UHD 620 and
      the "Main GPU" dropdown is populated
- [ ] set Main GPU → NVIDIA (D3); Intel stays unsupported upstream
- [ ] verify no new `monitor@astraext.github.io` errors in `journalctl --user`
- [ ] optionally file an upstream issue for Intel GPU support in
      `AstraExt/astra-monitor` (check for an existing one first)
