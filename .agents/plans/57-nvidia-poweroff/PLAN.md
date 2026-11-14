# Plan: NVIDIA power-off and reboot hangs

**Status: IN PROGRESS.** Drafted 2026-11-13. Builds on epics [37](../37-brave-webgpu/PLAN.md) and [38](../38-hybrid-gpu-offload/PLAN.md).

This plan fixes the shutdown hangs: the 90 s userspace wait and the kernel hang at `[nvidia-drm] Removing device`. Section 2 (Brave WebGPU on native Wayland) was tried and REJECTED, and section 3 is the GPU audit.

Progress is in [TODO.md](TODO.md).

## 1. Power-off hangs at `[nvidia-drm] ... Removing device`

### Evidence (console photo, 2026-11-13, uptime ~52 h with suspends)

- `systemd-shutdown` finishes: swaps off, loop/MD/DM detached, then
  `Not all file systems unmounted, 2 left` for two `/run/shutdown/mounts/<id>`
  entries, `Cannot finalize remaining file systems, continuing`, `Syncing`,
  `Powering off.` The two busy mounts are not the hang: systemd gives up on
  them and moves on, which is normal for the root and its bind mounts.
- The last line is `[drm] [nvidia-drm] [GPU ID 0x00000100] Removing device`,
  about 1.1 s after `Powering off`. That is the kernel's `device_shutdown()`
  calling the NVIDIA PCI shutdown hook. The `Unloading driver` line that
  follows in a normal teardown never appears.
- Bus `0x100` is `0000:01:00.0`, the T2000, which drives the external Samsung
  on DP-6 (epic 38). Module options are `nvidia-drm modeset=1 fbdev=1` and
  `NVreg_PreserveVideoMemoryAllocations=1 NVreg_UseKernelSuspendNotifiers=1`,
  on driver 595.71.05 with the open modules.

### Upstream status (read 2026-11-13)

All of these show the same path: `nv_pci_shutdown → nv_pci_remove_helper →
nv_drm_remove → nv_drm_dev_unload`, blocking on an nvkms lock or in GSP RPCs.
None has an NVIDIA fix.

- [open-gpu-kernel-modules#1486](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1486):
  the reporter dates the full teardown in `nv_pci_shutdown` to 595.45.04 and
  later, and says 590.48.01 does not do it. Their trigger is hibernation, not
  plain power-off.
- [#1222](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1222):
  plain shutdown hangs in `RestoreConsole → unixCallVideoBIOS`, which is the
  console-restore path. One reporter says suspend triggers it as well.
- [#1027](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1027):
  a plain reboot hang. A comment there reproduces it on 595.71.05, the same
  version as this host. The reporter says a oneshot that runs `rmmod` on the
  NVIDIA modules before reboot fixes it.
- [NVIDIA forum 382485](https://forums.developer.nvidia.com/t/hibernate-never-powers-off-stuck-in-nv-pci-shutdown-nv-drm-dev-unload-rtx-5070-laptop-nvidia-open-610-57/382485):
  two workarounds are confirmed there: `nvidia-drm.modeset=0`, and stopping
  the session and then running `modprobe -r` on the modules from a shutdown
  oneshot. `fbdev=0` did not help.
- [PR #1412](https://github.com/NVIDIA/open-gpu-kernel-modules/pull/1412) is
  a guard that only covers hibernation. It is unmerged.

### Decisions

- **D1** Add `systemd.services.nvidia-unload-at-shutdown`. It runs after
  `shutdown.target` and `umount.target`, so GDM, the user sessions and Docker
  have already stopped, and before `systemd-{poweroff,reboot,halt,kexec}`. It
  runs `rmmod` on `nvidia_peermem nvidia_uvm nvidia_drm nvidia_modeset
  nvidia`. With no module loaded, `device_shutdown()` has no NVIDIA hook to
  call. Output goes to kmsg, so the result is on the console. A module that
  will not unload is reported with its refcount and holders. A
  `TimeoutStartSec=20s` limit stops a hung `rmmod` from blocking shutdown
  forever. Before the `rmmod` loop the script unbinds the fbcon vtconsole
  (`/sys/class/vtconsole/vtcon*/bind`, matched by the name `frame buffer
  device`). `nvidia-drm` runs with `fbdev=1`, so fbcon can hold `nvidia_drm`,
  and `rmmod nvidia_drm` then fails "in use", which also makes `nvidia_modeset`
  and `nvidia` fail. The dummy console stays bound, so the kernel keeps a
  console.
  This is the workaround that #1027 and the forum both confirm for
  non-hibernation shutdowns. #1222 has one contrary report on a desktop
  Blackwell card, so success here is not guaranteed.
- **D2** Keep `modeset=1`. `modeset=0` is confirmed upstream but cannot work
  on this host: GNOME on Wayland needs KMS on the T2000, which drives the
  external display.
- **D3** Leave `fbdev=1` alone for now. The fbdev client teardown runs between
  `Removing device` and `Unloading driver`, which is exactly where this host
  stops. It is a suspect, but the one upstream test of `fbdev=0` did not help.
  It is fallback F2 below, not part of this change.
- **D4** The earlier `DefaultTimeoutStopSec=10s` change (same PR) still
  applies. It fixed the 90 s userspace wait, together with removing Desktop
  Icons NG. `KillUserProcesses` was dropped from that change: systemd stops
  every session scope at shutdown anyway, so the option only changes logout,
  and it would kill herdr-core and other jobs started from the desktop at
  logout. This hang happens later, in the kernel, which is why it shows up as a
  separate symptom.

### Fallback ladder, if D1 is not enough

- **F1** Check whether the hang needs a prior suspend: boot, do not suspend,
  power off. If it only follows a suspend, the suspend notifier state is
  involved (#1486, #1412).
- **F2** `hardware.nvidia.moduleParams.nvidia-drm.fbdev = 0`. This drops the
  NVIDIA framebuffer console; the Intel panel keeps its console.
- **F3** `hardware.nvidia.branch = "new_feature"`, which selects 590.48.01 in
  this channel. That is before the 595 teardown change, per #1486. The cost:
  kernel suspend notifiers need 595, so the module falls back to the
  `nvidia-suspend`/`nvidia-resume` services. Keep
  `PreserveVideoMemoryAllocations=1`, because the epic 38 resume fix depends
  on it. Then re-test suspend with the external monitor.

## 2. Brave WebGPU on native Wayland (REJECTED)

**REJECTED.** Brave stays on Xwayland with `vulkanSupport` from epic 37, and the overlay in `nix/configuration.nix` is unchanged from master. The reasoning below is kept as the original record, and the outcome paragraph supersedes it.

**Outcome (2026-11-13).** Measured on this host with Brave 1.95.104 (Chromium 153), channel nixos-26.05.10402, using `probe-brave-webgpu.mjs` in this folder. On native Wayland, WebGPU only gets the SwiftShader software adapter, `featureStatus` reports `vulkan: disabled_off`, and the probe prints FAIL. Adding `--ignore-gpu-blocklist`, `--enable-features=SkiaGraphite` or `--enable-features=Vulkan` on Wayland changed nothing. The Vulkan loader on Wayland did find the Intel ICD (`VK_LOADER_DEBUG` listed `[0] Intel(R) UHD Graphics (CML GT2)`), so the cause is that Chromium does not enable Vulkan there, not ICD discovery. The installed master Brave (Xwayland plus `vulkanSupport`) gets the Intel gen-9 hardware adapter, compute dispatch 41, and 0 `ProduceSkia`, context-lost or GPU-process errors, and the probe prints PASS. Decision: keep master's Brave, per epic 37. Decisions D5 to D9 and fallbacks W1 and W2 below are not applied.

### Why it was on Xwayland

Epic 37 set `vulkanSupport = true`, which adds `--enable-features=Vulkan`.
That feature moves Skia **compositing** to Vulkan, and the Wayland ozone
backend rejects that (`'--ozone-platform=wayland' is not compatible with
Vulkan`). On Wayland, every `<video>` frame then failed in `ProduceSkia`, so
Brave was forced onto X11. Under Xwayland, Chromium gets no touchpad
pinch/swipe gestures, no fractional scaling and no Wayland IME.

### What changed upstream

- Chrome 144 started WebGPU on Linux:
  ["WebGPU uses Vulkan and the rest of Chromium stays on OpenGL"](https://developer.chrome.com/blog/new-in-webgpu-144),
  enabled by default for Intel Gen12+ first.
- Chrome 147/148 extended it to
  ["modern NVIDIA drivers (2024-05) on Wayland"](https://developer.chrome.com/blog/new-in-webgpu-147-148).
- Brave in the channel is now 1.99.55, well past both. Its package also links
  nixpkgs' `vulkan-loader` (SYSCONFDIR `/run/opengl-driver/share`) and
  symlinks the bundled loader to it. So the `LD_LIBRARY_PATH` append from
  epic 37 is redundant, and `vulkanSupport` no longer prefixes
  `XDG_DATA_DIRS`.

### Decisions

- **D5** Drop `vulkanSupport` and the `--ozone-platform=x11` flag. Use
  `--ozone-platform-hint=auto`, so a native Wayland window, with X11 kept as
  the fallback outside a Wayland session.
- **D6** Add `--enable-unsafe-webgpu`. The UHD 620 is Gen9.5 (`8086:9bc4`),
  which is below Chrome's Gen12+ allowlist. Epic 37's control run without the
  `Vulkan` feature returned a null adapter, but it did not pass this flag, so
  the blocklist is the likely cause rather than a missing feature. The cost:
  WebGPU is exposed on a GPU Google has not validated, so a bad page can crash
  the GPU process.
- **D7** Keep the `VK_LOADER_DRIVERS_SELECT=intel*` pin (epic 37 D8). With
  GL compositing, Dawn on Intel keeps the WebGPU output on the same GPU as the
  compositor. `nvidia-offload brave` still reaches the T2000.
- **D8** Add `--enable-wayland-ime=true`. The package adds it only under
  `NIXOS_OZONE_WL`, which this host does not set. Do not add a second
  `--enable-features`: Chromium keeps only the last copy of a switch, and that
  would drop `AcceleratedVideoDecodeLinuxGL`.
- **D9** Verification is on the machine, with `probe-brave-webgpu.mjs`. It
  checks for a hardware WebGL2 renderer, a hardware WebGPU adapter, a compute
  dispatch that returns 41, video frames presented after six seeks, and zero
  `ProduceSkia` / `Context was lost` / GPU-process exits in the log. Software
  renderers fail it. The script was checked here only against a headless
  SwiftShader Chromium, which proves the CDP plumbing and the software
  rejection, not the hardware path.

### Fallback, if the probe fails on Wayland

- **W1** Read `featureStatus.webgpu` and the kept `browser.log`. If the
  adapter is null and the log shows no GPU errors, run the probe again with
  `-- --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,Vulkan`.
  The VA-API features are repeated because a later `--enable-features`
  replaces the wrapper's. That run shows whether WebGPU on this GPU needs
  the `Vulkan` feature, and what the feature costs on Wayland (the
  `ProduceSkia` count).
- **W2** If WebGPU on Wayland cannot be had without Vulkan compositing, the
  trade-off returns. Keep native Wayland by default, and add a second desktop
  entry, "Brave (WebGPU, X11)", with the old flags for the pages that need it.

## 3. GPU setup audit (2026-11-13)

| Item | State | Action |
|---|---|---|
| Driver | 595.71.05 open, `production` = `stable` in the channel | none; F3 is the downgrade route |
| Kernel | channel at 6.18.62 | none |
| PRIME offload, bus IDs | correct (epic 38) | none |
| Suspend (`PreserveVideoMemoryAllocations`, kernel notifiers) | in place for the DP-6 resume bug | keep; F3 changes the notifier part |
| `fbdev=1` | module default for 545+; on the hang path | F2 if D1 fails |
| Brave on Xwayland | lost gestures, fractional scaling, IME | none: native Wayland rejected (section 2 outcome), Brave stays on Xwayland |
| Brave `LD_LIBRARY_PATH` append | redundant only if the channel's Brave links the loader | kept: master's overlay is unchanged |
| Epic 37 D1 note that `vulkanSupport` prefixes `XDG_DATA_DIRS` | still applies: `vulkanSupport` stays on | none |
| Epic 38 risk note "no `hardware.nvidia.powerManagement`" | wrong for 26.05 (the option exists and is set) | noted here |
| Intel VA-API (`intel-media-driver`), no session `LIBVA_DRIVER_NAME` | correct (epic 38 D5) | none |
| `nvidia-offload` does not filter Vulkan on 595 | known; switcheroo uses `VK_LOADER_DRIVERS_SELECT` | none |
| T2000 always powered | required: it drives the external display | none |
