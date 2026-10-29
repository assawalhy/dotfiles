# Plan — Brave WebGPU ("No WebGPU adapter found")

**Status: NOT STARTED.** Drafted 2026-10-17, updated 2026-10-17 with a control
run that proves the Vulkan feature flag is required. Depends on epic
[38](../38-hybrid-gpu-offload/PLAN.md) for the ICD set it is verified against.
Progress is in [TODO.md](TODO.md).

## Goal
Make WebGPU usable in Brave on this host: `navigator.gpu.requestAdapter()` must
return the hardware adapter and a real compute dispatch must run on it, from the
normal (non-debug) Brave launch.

## Findings (verified 2026-10-17 by CDP probe, not speculation)
- Brave 153.1.95.104 on nixos-26.05 (`1e8bc658fc98`). WebGPU itself is enabled,
  but GPU status reports `vulkan: disabled_off`, `hardwareSupportsVulkan=false`,
  and `requestAdapter()` returns null.
- The GPU process cannot load the Vulkan loader: `Failed to load
  'libvulkan.so.1': cannot open shared object file`. Brave bundles
  `opt/brave.com/brave/libvulkan.so.1`, but the binary's RUNPATH has no
  `$ORIGIN`, and the 26.05 package has no `vulkan-loader` dependency, so the
  soname sits on neither the RUNPATH nor the wrapper's `LD_LIBRARY_PATH`.
- With the loader on `LD_LIBRARY_PATH` and `--enable-features=Vulkan`, Dawn
  still failed with `vkCreateInstance: Found no drivers!`. `/run/opengl-driver/lib`
  carries the Mesa ICDs but no loader, and the loader's own baked-in
  `/run/opengl-driver/share` fallback did not fire. Discovery worked only once
  `/run/opengl-driver/share` was on `XDG_DATA_DIRS`, or `VK_DRIVER_FILES` named
  an ICD file.
- Verified working, with a real compute dispatch (result 41, so a device was
  created and used, not merely enumerated):

  | ICD discovery | adapter | device | dispatch |
  |---|---|---|---|
  | `XDG_DATA_DIRS=/run/opengl-driver/share` | NVIDIA TU117 (nouveau/NVK) | ok | 41 |
  | `VK_DRIVER_FILES=<intel_icd>` | Intel gen-9 | ok | 41 |

- Probe matrix for the record: no flags -> null; `--use-webgpu-adapter=opengles`
  -> null; Wayland + Vulkan + reachable ICD -> works, with only a
  `'--ozone-platform=wayland' is not compatible with Vulkan` warning from the
  surface factory and WebGPU unaffected.
- Both verified runs above carried `--enable-features=Vulkan`, which is what
  `vulkanSupport` adds. A control run on 2026-10-17 set only `LD_LIBRARY_PATH`
  and `XDG_DATA_DIRS` with no feature flag: `chrome://gpu` reported
  `vulkan: disabled_off` and `requestAdapter()` returned null. The feature flag
  is therefore required, not only the loader and the ICDs.
- Epic [38](../38-hybrid-gpu-offload/PLAN.md) replaces nouveau with the
  proprietary driver (nvidia-open 595.71.05). That removes
  `nouveau_icd.x86_64.json` and adds `nvidia_icd.x86_64.json` under
  `/run/opengl-driver/share/vulkan/icd.d`, so a different adapter sits behind the
  same discovery path. The fix below does not depend on which ICD is there; only
  the adapter identity in the verification changes.
- nixpkgs 26.11 fixed this upstream: `vulkan-loader` is in `deps` (landing it on
  both the RPATH and the wrapper's `LD_LIBRARY_PATH`) and the bundled loader is
  replaced by a symlink to the patched one. The system channel is 26.05, and the
  repo's `unstable` pin (`4975466d`) predates that fix.

## Decisions
- **D1** `brave.override { vulkanSupport = true; }`. In 26.05 that adds
  `--enable-features=...,Vulkan` and `--prefix XDG_DATA_DIRS :
  /run/opengl-driver/share`, which is exactly the ICD discovery verified above.
  Rejected: `commandLineArgs = "--enable-features=Vulkan"` alone, which leaves
  the loader with no ICDs (reproduced).
- **D2** Put the loader on the wrapper's `LD_LIBRARY_PATH` from an overlay in the
  existing `nixpkgs.overlays`, mirroring upstream 26.11. Rejected: session-wide
  `environment.sessionVariables.LD_LIBRARY_PATH`, because LD_LIBRARY_PATH is
  searched before DT_RUNPATH and would change library resolution for every
  process; rejected: a `symlinkJoin` wrapper whose .desktop `Exec` keeps
  pointing at the unwrapped binary; rejected: taking brave from a newer nixpkgs,
  since the pin predates the fix and the 26.11 source in the store is not the
  channel.
- **D3** Stay on native Wayland. Rejected: the `--ozone-platform=x11` escape
  hatch from brave/brave-browser#55805, which degrades the whole browser to
  XWayland for a WebGPU-only concern and is unnecessary here (verified).
- **D4** Leave every ICD visible and let Dawn pick. After epic 38 the discrete
  card is reachable through `nvidia_icd.json`, and an explicit pin is a launch
  through `nvidia-offload`: the module's wrapper sets
  `__NV_PRIME_RENDER_OFFLOAD=1` and `__VK_LAYER_NV_optimus=NVIDIA_only`, which
  hides the Intel ICD from Vulkan. Rejected: hardcoding `VK_DRIVER_FILES` in the
  desktop entry, which would break WebGPU for a direct `brave` launch.
- **D5** Drop the `LD_LIBRARY_PATH` append once the channel reaches nixpkgs
  26.11; `vulkanSupport = true` stays needed until that package turns it on.
- **D6** VA-API is out of scope for this epic's code change, but epic 38 brings
  it into scope at the system level (`LIBVA_DRIVER_NAME=nvidia`). The nixpkgs
  brave package comment says Vulkan "seems to break VA-API", so that is now a
  live interaction rather than a non-issue (the previous text claimed decode was
  broken independently, which epic 38 changes). Verification: `chrome://gpu`
  video decode plus a real video in Brave. Fallback if Brave decode is broken:
  keep Brave for WebGPU and decode in Firefox, or drop the Vulkan flag and use
  Firefox for WebGPU.
- **D7** Order of work: epic [38](../38-hybrid-gpu-offload/PLAN.md) first (it
  changes the ICD set), then this epic, then epic 25.

## Milestones
0. Prerequisite: epic [38](../38-hybrid-gpu-offload/PLAN.md) deployed and
   rebooted, so the proprietary driver and its Vulkan ICD are in place.
1. Add the brave overlay inside `nixpkgs.overlays` in `nix/configuration.nix`
   (that list ends at line 245).
2. Deploy with `nix/update-nixos.sh`.
3. Inspect the generated wrapper: `Vulkan` in `--enable-features`, the
   `/run/opengl-driver/share` prefix, and `vulkan-loader` on `LD_LIBRARY_PATH`.
4. Probe the deployed wrapper with a throwaway profile over CDP: adapter
   non-null, device ok, dispatch 41. Record which adapter Dawn picked, then
   re-probe through `nvidia-offload brave` to confirm the pinned path.
5. User confirms WebGPU on a real page.

## Risks
- The wrapper is generated by `wrapGAppsHook3`; the append relies on the
  `gappsWrapperArgs` idiom that 232 packages in 26.05 already use, and milestone
  3 fails loudly if it did not take effect.
- Brave is rebuilt locally. It is a binary repack only, and its source tarball is
  already in the store.
- Wayland still refuses Vulkan for compositing, so one warning line stays in the
  log; WebGPU is unaffected.
- No re-login is needed for Brave, since the per-user profile symlink resolves
  after a switch, but a running Brave must be restarted.
- A future nixpkgs may change `vulkanSupport` semantics; milestone 3 catches that
  on the next rebuild.
- Enabling `Vulkan` in Brave turns on Vulkan rendering as well as WebGPU, which
  is the documented VA-API interaction in D6, and may cost battery on a hybrid
  laptop because Chromium can pick the discrete card for compositing. Recorded,
  not a blocker; D4's `nvidia-offload` path is the explicit alternative.

## Second failure: Meet backgrounds, 2026-10-29

The deploy in generation 49 did not fix Google Meet. Meet reported "Visual effects require WebGL" while `chrome://gpu` said `webgpu: enabled`. A CDP probe on the deployed wrapper found the real state: WebGL2 absent, `requestAdapter()` null, `vulkan: disabled_off`, and three GPU process restarts in the log.

Cause: with every ICD on the discovery path, Dawn enumerates both the Intel UHD 620 and the T2000, chooses the T2000 as the discrete device, and then fails in `SharedImageManager::ProduceSkia: Trying to produce a Skia representation from an incompatible backing: CompoundImageBacking`, followed by `Context was lost` and `exit_code=8704`. Chromium restarts the GPU process three times and then falls back to no hardware acceleration at all. That is why the failure is worse than before the epic: it takes WebGL down with WebGPU.

Measured matrix, one variable per run, CDP probe of `requestAdapter()`, a WebGL2 clear, and a WebGPU compute dispatch:

| ICD set / flag | WebGL2 | adapter | dispatch | GPU restarts |
|---|---|---|---|---|
| `intel_icd` only | on | gen-9 | 41 | 0 |
| `nvidia_icd` only | on | turing | 41 | 0 |
| `intel` + `nvidia` | off | null | n/a | 3 |
| `intel` + `nouveau` | on | gen-9 | 41 | 0 |
| `intel` + `lvp` | on | gen-9 | 41 | 0 |
| `VK_LOADER_DRIVERS_SELECT=intel*` | on | gen-9 | 41 | 0 |
| `VK_LOADER_DRIVERS_DISABLE=nvidia*` | on | gen-9 | 41 | 0 |
| `MESA_VK_DEVICE_SELECT=8086:9bc4` | off | null | n/a | 3 |
| `--disable-vulkan-surface` | off | null | n/a | 3 |
| `__NV_PRIME_RENDER_OFFLOAD=1` + both ICDs | on | turing | 41 | 0 |

The pairing matters, not the NVIDIA ICD alone: `nvidia_icd` by itself works, and `intel` plus any other ICD works. Only Intel together with NVIDIA breaks it, and only because Dawn then creates devices on both. `MESA_VK_DEVICE_SELECT` does not help because Chromium's Vulkan instance ignores it. Disabling the Vulkan surface does not help either, so the failure is in the shared image backing, not in surface creation.

Decision D8: the wrapper sets `VK_LOADER_DRIVERS_SELECT=intel*` unless the caller already set it or `__NV_PRIME_RENDER_OFFLOAD` is set. That pins Dawn to the display GPU, which is also the GPU the compositor runs on, so no cross-GPU shared image is created. The `__NV_PRIME_RENDER_OFFLOAD` guard keeps `nvidia-offload brave` on the T2000, which was measured to work with both ICDs present because the Optimus layer pins the device first.

Verified on the built package, not on a hand-written command: the wrapper from the overlay carries the `--run` line, plain launch gives WebGL2 on, adapter gen-9, dispatch 41, zero restarts, and `__NV_PRIME_RENDER_OFFLOAD=1` on the same wrapper gives adapter turing, dispatch 41, zero restarts.

Rejected: dropping the NVIDIA ICD from `XDG_DATA_DIRS` with `VK_DRIVER_FILES`, because that would break `nvidia-offload brave` and any other Vulkan client in the session. Rejected: `--disable-vulkan-surface` and `MESA_VK_DEVICE_SELECT`, both measured to leave the crash in place.
