# TODO — Astra Monitor "No GPU found" (GPU detection)

**NOT STARTED — recorded only, handled later.** Nothing below has been applied.
See [PLAN.md](PLAN.md) and issue
[#27](https://github.com/assawalhy/dotfiles/issues/27). Findings are already
verified (2026-10-07), so this needs no re-research when picked up.

- [ ] add `pciutils` (+ `intel-gpu-tools`) to `environment.systemPackages` in
      `nix/configuration.nix` (D1)
- [ ] deploy: `nix/update-nixos.sh` (switch)
- [ ] re-login — the Shell memoises `lspciCached`, so a reload is required
- [ ] confirm the GPU section lists `card1` (NVIDIA) + `card2` (Intel) and the
      "Main GPU" dropdown is populated
- [ ] decide the outcome (D2/D3): leave Intel unsupported / enable the NVIDIA
      driver / set Main GPU → None
- [ ] verify no new `monitor@astraext.github.io` errors in `journalctl --user`
- [ ] optionally file an upstream issue for Intel GPU support in
      `AstraExt/astra-monitor` (check for an existing one first)
