# TODO — Hybrid GPU: NVIDIA open driver + PRIME offload

**IN PROGRESS.** Drafted 2026-10-17, approved and deployed as generation 49. The
reboot, the runtime checks and the issue filing remain; see [PLAN.md](PLAN.md)
for evidence and rejected alternatives.

- [x] add the `hardware.nvidia` block, `services.xserver.videoDrivers` and
      `services.switcherooControl.enable` to `nix/configuration.nix` (D1 to D4,
      D8). The two VA-API session variables were added here and removed on
      2026-10-20; see D5 and the post-reboot findings.
- [x] add `hardware.nvidia-container-toolkit.enable = true` next to
      `virtualisation.docker.enable` (D6)
- [x] append `libva-utils`, `vulkan-tools`, `cudaPackages.cuda_nvcc`,
      `cudaPackages.cuda_cudart` to the existing `environment.systemPackages`
      list (D7, D9)
- [x] write `.agents/plans/38-hybrid-gpu-offload/cuda-smoke.cu` (a ~20 line
      vector add that prints its result) (D7)
- [x] build the system closure. `sudo` is not passwordless here and
      `nix/update-nixos.sh` needs root for the rsync, so the build ran from a
      scratch mirror of `nix/` plus `/etc/nixos/hardware-configuration.nix`.
      `nixos-rebuild -f` is wrong for this (it evaluates the file with
      `--attr config.system.build.toplevel`, which a plain `configuration.nix`
      does not expose); the working command is
      `NIXOS_CONFIG=/tmp/opencode/nixos-preview/configuration.nix nix-build
      '<nixpkgs/nixos>' -A config.system.build.toplevel`.
      Result: `/nix/store/9gwj6ch5mpl0mjp925a8nd88bb2h6p7h-nixos-system-nixos-26.05.10402.1e8bc658fc98`.
      No local nvidia build; the new kernel modules for 6.18.52 are in the
      closure and `nouveau` is gone from them.
- [x] `nix/update-nixos.sh` switch (generation 49), then confirm
      `/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json`,
      `/run/opengl-driver/lib/dri/nvidia_drv_video.so` and `nvidia-offload` exist.
      All three are there; `nvidia-smi`, `vulkaninfo`, `vainfo`, `nvcc` and
      `switcherooctl` resolve on PATH. `switcheroo-control.service` is up and
      lists both GPUs, but tags the T2000 `Discrete: no` while `nouveau` still
      owns it (3.0's udev rule tags `DRIVERS=="nvidia"` unconditionally, and its
      nouveau helper probe declines) - expect `Discrete: yes` after the reboot.
      The switch reported `nvidia-container-toolkit-cdi-generator.service`
      failed ("failed to initialize NVML: Driver Not Loaded"), which is the same
      pre-reboot state; it must pass after the reboot.
      GDM was not restarted (`restartIfChanged = false`), so the session survived.
- [x] reboot happened (2026-10-20). The driver is live: `nvidia-smi` reports the
      T2000 on 595.71.05, `nouveau` is gone, the panel is still on `i915`, and the
      CDI generator is active. The first `verify.sh` run found three gaps, all
      since fixed in the config and the script:
      `nvidia-offload` does not pin Vulkan (use `VK_LOADER_DRIVERS_SELECT`),
      `switcheroo` does not tag the card discrete (missing udev rules), and
      `nvcc` cannot find `cuda_runtime.h` (cudart headers not on its path).
- [x] fix the video regression found at the same time: install
      `intel-media-driver` and drop the session-wide `LIBVA_DRIVER_NAME=nvidia`
      override, so Chromium decodes on the display GPU instead of the T2000
      (frozen tab, `eglCreateImage 0x00003009`). Add
      `services.udev.packages = [ pkgs.switcheroo-control ]`. Reproduced and
      compared with a local H.264 file before touching the config.
- [x] rebuild the fix:
      `/nix/store/gfv82m3ngw9m1lr6hql64sjj8ywvkgik-nixos-system-nixos-26.05.10402.1e8bc658fc98`.
      It carries `30-discrete-gpu.rules`, `intel-media-driver-26.1.6` in the
      graphics driver farm next to `nvidia_drv_video.so`, and no
      `LIBVA_DRIVER_NAME` in any of its `etc` files.
- [ ] switch it. The agent sandbox runs with `no_new_privs`, so `sudo` refuses
      there; the user has to run `nix/update-nixos.sh` in their own terminal.
      Then log out and back in, because `environment.sessionVariables` is read
      by the systemd user manager at login and the running session still holds
      the old value. Then run
      `.agents/plans/38-hybrid-gpu-offload/verify.sh`. It checks GNOME Wayland
      with the panel on `i915`, `nouveau` gone, `nvidia-smi` on 595.71.05, both
      adapters in `vulkaninfo`, NVIDIA only under `VK_LOADER_DRIVERS_SELECT`,
      H.264/HEVC on both render nodes, no VA-API override in the shell or
      gnome-shell, the CUDA smoke ending in OK, the CDI generator active, and
      switcheroo tagging the T2000 discrete.
      `GPU_VERIFY_DOCKER=1 .agents/plans/38-hybrid-gpu-offload/verify.sh` adds
      the `docker run --device nvidia.com/gpu=all` check, which pulls the CUDA
      base image.
- [ ] user confirms a real workload on the dGPU (Blender render, or the GNOME
      "Launch Using Discrete Graphics Card" entry) and that YouTube playback no
      longer freezes the tab
- [ ] suspend regression on the discrete output: the Samsung on DP-6 goes black
      with only a cursor after resume, and replugging does not help. Cause:
      `hardware.nvidia.powerManagement.enable` was never set, so the driver kept
      its defaults (`PreserveVideoMemoryAllocations: 2`,
      `UseKernelSuspendNotifiers: 0`) and lost video memory across S3 while
      nv_drm kept the mode set. Fixed in configuration.nix; the config now
      evaluates to
      `options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UseKernelSuspendNotifiers=1`.
      Needs a deploy and a reboot, then a suspend/resume cycle as the live check.
- [ ] file a GitHub issue for the hybrid GPU change and link it from PLAN.md
- [ ] then run epic 37 (Brave WebGPU), whose ICD set changes under this driver,
      and epic 25 (Astra panel), which gets `nvidia-smi` from here
- [ ] follow-up, not in this epic: Steam and gaming (needs
      `hardware.graphics.enable32Bit` and per-game launch options), and a
      CUDA-enabled ML stack (needs a package decision)
