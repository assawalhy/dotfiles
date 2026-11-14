# TODO: NVIDIA power-off and reboot hangs

Drafted 2026-11-13. See [PLAN.md](PLAN.md).

- [x] add `systemd.services.nvidia-unload-at-shutdown` (D1). Checked by
      evaluation: the unit renders with `DefaultDependencies=false`, it is
      ordered after `shutdown.target umount.target` and before `final.target`
      and the four `systemd-*` services, it is wanted by poweroff, reboot, halt
      and kexec, and `bash -n` passes on the script
- [ ] unbind the fbcon vtconsole at the start of the unload script, so fbcon
      does not hold `nvidia_drm` (`fbdev=1`) and make `rmmod` fail "in use"
- [x] drop `KillUserProcesses` from the shutdown-hang change: systemd stops
      every session scope at shutdown anyway, and the option would kill
      herdr-core and other jobs started from the desktop at logout
- [x] ~~Brave overlay: native Wayland, `--enable-unsafe-webgpu`~~ REVERTED: on native Wayland WebGPU only gets the SwiftShader adapter (`vulkan: disabled_off`) and the probe fails, so master's overlay (Xwayland plus `vulkanSupport`) is restored
- [x] write `.agents/plans/57-nvidia-poweroff/probe-brave-webgpu.mjs` (D9), kept as the measurement tool. Used on this host: PASS on master's Brave (Intel adapter, dispatch 41), FAIL on native Wayland (SwiftShader)
- [x] whole-system evaluation against nixos-26.05.13936 with a stub
      hardware-configuration
- [x] ~~on the machine: build and probe the Wayland Brave~~ NOT APPLICABLE: measured, Wayland Brave rejected
- [x] ~~probe again through `nvidia-offload`~~ NOT APPLICABLE: no Wayland Brave to probe
- [x] ~~user: pinch zoom, Meet backgrounds, webgpureport.org on Wayland Brave~~ NOT APPLICABLE: Brave stays on Xwayland
- [ ] power-off and reboot several times, including after a suspend with the
      external monitor connected. The console must show
      `nvidia-unload: unloaded …` lines and power off. If it prints
      `could not unload`, record the holders. If it still hangs, go to F1 to F3
- [x] ~~tick the last unchecked items in epic 37's TODO once the probe passes~~ NOT APPLICABLE: epic 37's overlay is the one in use, its remaining items are tracked there
