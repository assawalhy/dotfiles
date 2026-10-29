# Plan — Hybrid GPU: NVIDIA open driver + PRIME offload

**Status: NOT STARTED.** Drafted 2026-10-17 from verified facts. Progress is in
[TODO.md](TODO.md).

Goal from the user (2026-10-17): use the built-in Intel GPU **and** the NVIDIA
Quadro for heavy GPU work (CUDA/ML, Blender, video encode, gaming), plus Docker
GPU containers, hardware video decode, and the Astra Monitor NVIDIA panel.

## Hardware (verified 2026-10-17, not speculation)

| PCI | device | driver today | role today |
|---|---|---|---|
| `0000:00:02.0` | Intel CometLake UHD 620 (`0x9bc4`) | `i915` | drives `eDP-1`, runs the GNOME Wayland session |
| `0000:01:00.0` | NVIDIA TU117GLM Quadro T2000 Mobile (`10de:1fb8`), 4 GiB | `nouveau` (GSP RM 570.144) | render offload only, every connector disconnected |

- Host is an HP ZBook Fury 15 G7 (the machine is named in the `services.fprintd`
  comment in `nix/configuration.nix`).
- `card0`/`card1` numbering swaps between boots. The PCI addresses above are the
  stable keys; epic 25's table used the card numbers and named the wrong GPU.
- **Correction:** issue #27 calls this card a "Quadro P2000". `10de:1fb8` is the
  Turing TU117 **Quadro T2000 Mobile**, so the P2000 label in issue #27 and in
  epic 25 is wrong.
- Both GPUs already work. Intel renders the whole desktop, and the NVIDIA card
  already has a working Vulkan driver through nouveau/NVK: a WebGPU compute
  dispatch on it returned 41. Nothing is "off"; what is missing is the
  proprietary feature set and real clocking.

## Why the proprietary driver is the answer

`nouveau` cannot do CUDA or NVENC/NVDEC, has no OptiX, and never reclocks the
card, so it runs at boot clocks. "Heavy GPU work" is precisely where it fails.
The user asked for all of those workloads, so the driver has to change.

## Decisions

- **D1** `hardware.nvidia.open = true`, NVIDIA's open kernel modules. Verified in
  the channel: driver **595.71.05**, `linuxPackages.nvidia_x11.open` for kernel
  **6.18.52** is in the binary cache (22.2 MiB fetch, no local build), and the
  userspace package is substitutable too. Open modules are what NVIDIA
  recommends for Turing. Rejected: closed `nvidia` kernel modules (same
  userspace, no benefit here, and they lag kernel support); rejected: staying on
  nouveau (no CUDA).
- **D2** Intel stays primary. The NVIDIA GPU is used on demand through PRIME
  render offload, with the `nvidia-offload` wrapper that the module generates
  when `offload.enableOffloadCmd = true`. Rejected: `prime.sync.enable`, which
  needs a hardware MUX, keeps the dGPU always on, and is an X11-era setup;
  rejected: `prime.reverseSync.enable` (only for displays wired to the dGPU,
  which is not the case here, every NVIDIA connector is disconnected); rejected:
  BIOS discrete-only mode, which would cost battery life and remove the working
  Intel Wayland path.
- **D3** Bus IDs `PCI:0:2:0` (Intel) and `PCI:0:1:0` (NVIDIA). The option docs
  want decimal, and these values are single digits, so hex and decimal coincide.
  The module asserts on them when PRIME is enabled, and X11 offload needs them.
- **D4** Rely on module defaults where they are already correct, and verify each
  one instead of restating it: `modesetting.enable` defaults true for driver
  535+ (nvidia_drm KMS, fixes Optimus tearing, needed for Wayland),
  `gsp.enable` defaults true with the open modules, `videoAcceleration` defaults
  true and therefore pulls `nvidia-vaapi-driver` into the graphics driver link
  farm.
- **D5** Hardware video decode: keep the `videoAcceleration` default, and install
  `intel-media-driver` so the display GPU (Intel) has a VA-API driver of its own.
  Do not set `LIBVA_DRIVER_NAME` session-wide. Mechanism verified: libva is built
  with `--with-drivers-path=<driverLink>/lib/dri`, and the driver link farm is
  `/run/opengl-driver`, so both `iHD_drv_video.so` and `nvidia_drv_video.so` are
  found and libva picks the driver matching the render node.
  Superseded on 2026-10-20: D5 originally forced
  `LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct` session-wide, because Intel
  VA-API appeared broken. That was a missing userspace driver, not a hardware
  limit: with `intel-media-driver` installed, Intel reports H.264/HEVC decode and
  encoders. The forced NVIDIA path made Chromium decode on the T2000 while its
  compositor ran on Intel; the frame import failed
  (`eglCreateImage failed 0x00003009`, `ProduceSkiaGanesh failed to create GL
  representation`, `Unable to initialize binding from pixmap`) and video playback
  froze the tab. Reproduced with a local H.264 file: the NVIDIA path presented 35
  frames and stalled while the decoder produced 305; the Intel path presented
  frames normally with zero GPU errors.
  Named fallback for NVDEC on the dGPU: set `LIBVA_DRIVER_NAME=nvidia` and
  `NVD_BACKEND=direct` in the wrapper of the specific app launched through
  `nvidia-offload`, never for the session. Turing decodes H.264, HEVC and VP9,
  but **not AV1**; CometLake decodes H.264, HEVC and VP9 as well.
- **D6** Docker GPU access: `hardware.nvidia-container-toolkit.enable = true`,
  set next to the existing `virtualisation.docker.enable`.
- **D7** CUDA: install `cudaPackages.cuda_nvcc` and `cudaPackages.cuda_cudart`
  (compile plus runtime, the minimal set) and keep a short `cuda-smoke.cu` in
  this epic so the check is reproducible after upgrades. These are the CUDA 12.9
  redistributables, checked on 2026-10-17: about 82 MiB of downloads, unpacked by
  3 and 7 small derivations, no compilation. CUDA 12.9 runs on driver 595.
  Rejected: `nixpkgs.config.cudaSupport = true`, which rebuilds a large part of
  the CUDA package set from source with no cache, for a machine that may need one
  or two CUDA packages. A CUDA-enabled ML stack (torch and friends) is a separate
  epic once the exact package is chosen, and can use a per-package override
  instead.
- **D8** `services.switcherooControl.enable = true`, so GNOME offers "Launch
  Using Discrete Graphics Card". Verified that the nvidia module does not enable
  it and `switcherooctl` is not installed today. This is the closest thing to
  "seamless" that a MUXless Optimus laptop has; automatic per-app GPU selection
  does not exist.
- **D9** Add `libva-utils` (`vainfo`) and `vulkan-tools` (`vulkaninfo`) to the
  existing `environment.systemPackages` list for verification.
- **D10** Scope boundary, named rather than silently dropped: Steam and gaming
  (`programs.steam.enable`, 32-bit graphics, per-game launch options) is a
  follow-up epic, because it pulls in `hardware.graphics.enable32Bit` and a
  large closure. This epic ends with the driver and the offload mechanism
  proven, which is the prerequisite for it.

## The config change

One block in `nix/configuration.nix` after `services.libinput.enable` (line
116), one line after `virtualisation.docker.enable` (line 257), and four
packages appended to the existing `environment.systemPackages` list (line 325).

```nix
  # Hybrid GPU (HP ZBook Fury 15 G7). Intel CometLake UHD 620 at 0000:00:02.0
  # drives eDP-1 and the GNOME Wayland session; the NVIDIA Quadro T2000 (TU117,
  # 0000:01:00.0) has no connected output and is used per application. The
  # proprietary driver is the only route to CUDA, NVDEC/NVENC, OptiX and real
  # clocking (nouveau leaves the card at boot clocks). `open` selects NVIDIA's
  # open kernel modules, the vendor recommendation for Turing, present in the
  # binary cache for kernel 6.18.52.
  hardware.nvidia = {
    open = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # provides `nvidia-offload`
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:0:1:0";
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # GNOME's "Launch Using Discrete Graphics Card" needs this D-Bus service.
  services.switcherooControl.enable = true;

  # The module ships the service but not the package's udev rules, so the
  # `switcheroo-discrete-gpu` tag never lands.
  services.udev.packages = [ pkgs.switcheroo-control ];

  # Intel VA-API (iHD) for the display GPU, so each card decodes on its own
  # device. Do not force LIBVA_DRIVER_NAME session-wide: that decodes on the
  # T2000 while the compositor runs on Intel, and Chromium's frame import fails.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
```

and, next to `virtualisation.docker.enable = true;`:

```nix
  # GPU devices inside containers.
  hardware.nvidia-container-toolkit.enable = true;
```

## Milestones

1. Apply the config change.
2. `nix/update-nixos.sh build` (build only, nothing switched). Confirm the NVIDIA
   kernel module and userspace come from the cache, with no local build.
3. `nix/update-nixos.sh` switch, then check `/run/opengl-driver`:
   `share/vulkan/icd.d/nvidia_icd.json`, `lib/dri/nvidia_drv_video.so`, and
   `nvidia-offload` on PATH.
4. Reboot.
5. Verify, in this order: the GNOME Wayland session still comes up with Intel
   driving `eDP-1`; `nouveau` is no longer loaded; `nvidia-smi` reports the
   T2000 on driver 595.71.05; `vulkaninfo --summary` lists both devices and
   `nvidia-offload vulkaninfo --summary` lists only NVIDIA; `vainfo` initialises
   with the nvidia driver and lists H.264/HEVC profiles; `cuda-smoke.cu` compiles
   with `nvcc` and prints the expected sum; a CUDA container sees the GPU.
6. Ask the user to confirm a heavy real workload (a Blender render, or the
   GNOME "Launch Using Discrete Graphics Card" entry appearing).
7. Hand over to epic 37 (Brave WebGPU) and epic 25 (Astra Monitor panel), both
   of which now have their prerequisite met.

## Risks

- Boot risk is real but bounded: a driver and kernel mismatch drops the session
  to a TTY. systemd-boot keeps the previous generations, and the escape hatch is
  selecting the previous generation, then either `hardware.nvidia.open = false`
  or reverting this change.
- Every future kernel bump needs a matching module. The channel kernel 6.18.52
  has it cached today; a bump may rebuild the module locally until the cache
  catches up.
- nixos-26.05 has no `hardware.nvidia.powerManagement` (only
  `powerManagement.kernelSuspendNotifier`, which defaults on for open modules on
  595+), so the dGPU stays powered while idle. That is a battery cost, and there
  is no supported switch to turn it off.
- Offload is per application. Nothing runs on the dGPU unless it is asked to,
  which is the intended behaviour but also means "everything automatically" is
  not achievable on this hardware.
- Video decode must stay on the display GPU. Any session-wide `LIBVA_DRIVER_NAME`
  reintroduces the frozen-tab bug; see D5.
- Brave is a cross-epic wrinkle: epic 37 enables `--enable-features=Vulkan` for
  WebGPU. On 2026-10-20 a local H.264 file presented frames normally with the
  Intel VA-API driver, so the flags are not the cause of the freeze by
  themselves.
- `hardware.nvidia-container-toolkit.enable` configures the Docker runtime. The
  container check needs a network pull of a CUDA base image.

## Post-reboot findings (2026-10-20)

- The driver, Vulkan enumeration, CUDA and CDI all work on generation 50.
- The session-wide NVIDIA VA-API override was the cause of a real regression:
  Chromium video playback froze the tab and left a stale surface, with
  `eglCreateImage failed 0x00003009` and `ProduceSkiaGanesh failed to create GL
  representation` in the journal. D5 was rewritten and the override removed.
- `nvidia-offload vulkaninfo` still lists every adapter: driver 595's implicit
  optimus layer is loaded by loader 1.4.341 but no longer filters devices.
  `VK_LOADER_DRIVERS_SELECT='*nvidia*'` is the working mechanism, and it is what
  switcheroo-control exports for the discrete GPU.
- `switcherooctl` reported `Discrete: no` for both GPUs because the NixOS module
  never installs `30-discrete-gpu.rules`. Fixed with
  `services.udev.packages = [ pkgs.switcheroo-control ]`. GNOME 50 keys its menu
  entry off `HasDualGpu`, which was already true.
- Plain `nvcc` cannot find `cuda_runtime.h`; the cudart headers live in the
  `cuda_cudart` output that `environment.systemPackages` does not expose on the
  compiler search path. `verify.sh` now locates it in the system closure and
  passes `-I`/`-L`. A turnkey compiler belongs in the ML epic as a devShell.

## Suspend regression on the discrete output, 2026-10-29

The external Samsung is connected to DP-6 of the T2000 (`card0-DP-6`), not to an Intel output, so after this epic the discrete GPU owns a display. Suspend then breaks that display: after resume the monitor shows only a cursor on a black screen, and unplugging and replugging the cable does not recover it.

Kernel evidence from the resume at 05:50:32:

```
NVRM: Xid (PCI:0000:01:00): 13, pid=3821, name=.gnome-shell-wr, Graphics Exception: Shader Program Header 18 Error
[drm:nv_drm_atomic_apply_modeset_config] Failed to initialize semaphore for plane fence
[drm:nv_drm_atomic_commit] Failed to apply atomic modeset. Error code: -11
[drm:nv_drm_atomic_commit] Flip event timeout on head 0
```

The last line repeats every time the display is touched afterwards, and the state never recovers.

Cause: `hardware.nvidia.powerManagement.enable` was never set, so the module emitted no suspend handling. The driver reported its own defaults, `PreserveVideoMemoryAllocations: 2` and `UseKernelSuspendNotifiers: 0`, and `/proc/driver/nvidia/suspend` existed but nothing called it. The GPU loses its video memory and its fence state across S3 while nv_drm keeps the mode set, which is exactly the failure the NVIDIA power management documentation describes.

Fix: `hardware.nvidia.powerManagement.enable = true`. On driver 595 with the open modules the module also defaults `kernelSuspendNotifier` to true, so it sets both `NVreg_PreserveVideoMemoryAllocations=1` and `NVreg_UseKernelSuspendNotifiers=1` and skips the `nvidia-suspend`/`nvidia-resume` systemd services, letting the kernel notifier handle the transition.

Verified by evaluating the config, since the sandbox cannot run `nixos-rebuild`:

```
"modprobe":"...options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UseKernelSuspendNotifiers=1\noptions nvidia-drm fbdev=1 modeset=1"
"powerManagement":true
"kernelSuspend":true
```

Deploy needs `nix/update-nixos.sh` and a reboot, because the parameters are module options. Then a suspend and resume cycle is the live check.

Rejected: `powerManagement.finegrained`, which is RTD3 for an unused card. The T2000 drives a display here, so powering it down is not an option.
