# Plan — Astra Monitor "No GPU found" (GPU detection)

**Status: NOT STARTED.** Recorded 2026-10-07, updated 2026-10-17 (hardware
correction and the epic 38 dependency), handled later.
Tracked as issue [#27](https://github.com/assawalhy/dotfiles/issues/27).

## Goal
Stop Astra Monitor from reporting "No GPU found" on this machine, and decide
whether any GPU is actually monitorable here.

## Findings (verified 2026-10-07, not speculation)
- Extension: Astra Monitor **v56** (`monitor@astraext.github.io`), enabled via
  the `programs.dconf` defaults from epic 13. That preset only surfaces RAM % +
  CPU package temperature, so the GPU panel is decorative today.
- `Utils.getGPUsList()` (`src/utils/utils.js:939`) returns `[]` when
  `Utils.hasLspci()` is false. `lspci` ships in `pkgs.pciutils`, which is **not**
  in `environment.systemPackages` → the GPU list is *always* empty here.
- Empty list → prefs "Main GPU" dropdown has no entries → `gpu-main` never set
  (verified empty via `dconf read /org/gnome/shell/extensions/astra-monitor/gpu-main`)
  → `gpu-data` stays `[]` → `src/gpu/gpuMenuComponent.js:57` renders the
  **"No GPU found"** label. Not a crash, not a driver fault.
- `canMonitorGpu()` (`utils.js:423`) is vendor-gated: AMD needs `amdgpu_top`,
  NVIDIA needs `nvidia-smi`, **everything else returns `false`**.
  `Utils.hasIntelGpuTop()` exists at `utils.js:491` but is never called in v56.
  `RELEASES.md:240`: *"Intel GPUs are not supported yet for a lack of hardware
  to test on."*
- Hardware (read from `/sys/class/drm`; the `cardN` numbering swaps between
  boots, the PCI addresses do not):

  | PCI | vendor | device |
  |---|---|---|
  | `0000:01:00.0` | `0x10de` | NVIDIA TU117GLM Quadro T2000 Mobile, 4 GiB (nouveau) |
  | `0000:00:02.0` | `0x8086` | Intel CometLake UHD 620, drives `eDP-1` |

  Corrected 2026-10-17: the first table here called the NVIDIA card a "Quadro
  P2000" and used card numbers. `10de:1fb8` is the Turing TU117 Quadro T2000.
  Issue #27 carries the same wrong name.
- `nix/configuration.nix` configured **no NVIDIA driver** when this was written,
  so `nvidia-smi` was absent too. Epic
  [38](../38-hybrid-gpu-offload/PLAN.md) changes that: it installs the
  proprietary driver (nvidia-open 595.71.05) for real GPU work, which puts
  `nvidia-smi` on the system and makes `canMonitorGpu()` return true for this
  card. The driver is coming for CUDA, NVDEC and real clocking, not for the
  panel; the monitorable panel is a side effect.
- `lspciCached` is memoised inside the Shell process, so the extension must be
  reloaded (re-login on Wayland) after the tool appears.

## Decisions (D1 and D4 firm; D2 superseded by epic 38 on 2026-10-17)
- **D1** Add `pciutils` (+ `intel-gpu-tools` for a future Astra release) to
  `environment.systemPackages`. Fixes the empty enumeration and the misleading
  label; Intel then reports "not supported" honestly. Rejected: leaving the list
  empty (the label actively misinforms).
- **D2** Do **not** enable the NVIDIA driver *for this panel*. Superseded on
  2026-10-17: epic 38 installs that driver for CUDA, NVDEC and real clocking, so
  `nvidia-smi` arrives without this epic asking for it. No extra work here
  beyond selecting the card in the dropdown.
- **D3** Set *Main GPU → NVIDIA* (the T2000) once epic 38 has rebooted. Intel
  remains unsupported upstream (`RELEASES.md:240`), so NVIDIA is the only
  monitorable card on this host. Fallback if the NVIDIA panel misreports: set
  *Main GPU → None*, which hides the section instead of showing a permanent
  "No GPU found".
- **D4** Keep this a local config fix, not an extension patch — the extension
  behaves as documented; the missing piece is a package we simply do not install.

## Milestones
0. Prerequisite: epic [38](../38-hybrid-gpu-offload/PLAN.md) deployed and
   rebooted, so `nvidia-smi` exists.
1. Add `pciutils` (+ `intel-gpu-tools`) to `nix/configuration.nix`.
2. `nix/update-nixos.sh` → switch.
3. Re-login; confirm the GPU section lists both cards and the dropdown is usable.
4. Set *Main GPU → NVIDIA* (D3).
5. Verify no new `monitor@astraext.github.io` errors in `journalctl --user`.

## Risks
- Re-login required; the Shell memoises the `lspci` probe.
- The GPU panel may legitimately stay unmonitorable — that is an upstream gap
  (`AstraExt/astra-monitor`), not something our config can fix.
- Adding `intel-gpu-tools` is harmless but unused by v56; it only pays off if
  upstream lands Intel support.
