# TODO — NVIDIA power-off hang, Brave WebGPU on Wayland

Drafted 2026-11-13. See [PLAN.md](PLAN.md).

- [x] add `systemd.services.nvidia-unload-at-shutdown` (D1). Checked by
      evaluation: the unit renders with `DefaultDependencies=false`, it is
      ordered after `shutdown.target umount.target` and before `final.target`
      and the four `systemd-*` services, it is wanted by poweroff, reboot, halt
      and kexec, and `bash -n` passes on the script
- [x] Brave overlay: drop `vulkanSupport`, `--ozone-platform=x11` and the
      `LD_LIBRARY_PATH` append; add `--ozone-platform-hint=auto`,
      `--enable-wayland-ime=true` and `--enable-unsafe-webgpu`; keep the Intel
      ICD pin (D5 to D8). Built brave-1.99.55: the exec line has no `Vulkan`
      feature, keeps both VA-API features, and has the new flags and the
      `--run` pin. `libvulkan.so.1` links to the channel's vulkan-loader
- [x] write `probe-brave-webgpu.mjs` (D9). Checked against a headless
      SwiftShader Chromium 153: the CDP flow completes and a software adapter
      is reported as FAIL
- [x] whole-system evaluation against nixos-26.05.13936 with a stub
      hardware-configuration
- [ ] on the machine, from the repo root in the GNOME session:
      `nix/update-nixos.sh build`, then
      `node .agents/plans/53-wayland-webgpu/probe-brave-webgpu.mjs ./result/sw/bin/brave`.
      It must print PASS with an Intel adapter. Then `nix/update-nixos.sh`
- [ ] probe again through `nvidia-offload`:
      `nvidia-offload node .agents/plans/53-wayland-webgpu/probe-brave-webgpu.mjs`.
      Expect the turing adapter
- [ ] user: touchpad pinch zoom and two-finger back/forward in Brave; Meet
      backgrounds; https://webgpureport.org
- [ ] power-off and reboot several times, including after a suspend with the
      external monitor connected. The console must show
      `nvidia-unload: unloaded …` lines and power off. If it prints
      `could not unload`, record the holders. If it still hangs, go to F1–F3
- [ ] tick the last unchecked items in epic 37's TODO once the probe passes
