# Plan — Astra Monitor "No GPU found" (GPU detection)

**Status: NOT STARTED.** Recorded 2026-10-07, handled later.
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
- Hardware (read from `/sys/class/drm`):
  | card | PCI | vendor | device |
  |---|---|---|---|
  | `card1` | `0000:01:00.0` | `0x10de` | NVIDIA Quadro P2000 |
  | `card2` | `0000:00:02.0` | `0x8086` | Intel UHD 620 — drives `eDP-1` |
- `nix/configuration.nix` configures **no NVIDIA driver**, so `nvidia-smi` is
  absent too.
- `lspciCached` is memoised inside the Shell process, so the extension must be
  reloaded (re-login on Wayland) after the tool appears.

## Decisions (proposed — revisit when this is picked up)
- **D1** Add `pciutils` (+ `intel-gpu-tools` for a future Astra release) to
  `environment.systemPackages`. Fixes the empty enumeration and the misleading
  label; Intel then reports "not supported" honestly. Rejected: leaving the list
  empty (the label actively misinforms).
- **D2** Do **not** enable the NVIDIA driver just to feed a stats panel. Unfree
  driver + reboot on a hybrid laptop, for a panel epic 13 does not use. Revisit
  only if GPU metrics are genuinely wanted.
- **D3** Interim UI answer if nothing is monitorable: set *Main GPU → None* to
  hide the section rather than showing a permanent "No GPU found".
- **D4** Keep this a local config fix, not an extension patch — the extension
  behaves as documented; the missing piece is a package we simply do not install.

## Milestones
1. Add `pciutils` (+ `intel-gpu-tools`) to `nix/configuration.nix`.
2. `nix/update-nixos.sh` → switch.
3. Re-login; confirm the GPU section lists both cards and the dropdown is usable.
4. Choose per D3: Intel (unsupported) / NVIDIA (needs driver, D2) / None.
5. Verify no new `monitor@astraext.github.io` errors in `journalctl --user`.

## Risks
- Re-login required; the Shell memoises the `lspci` probe.
- The GPU panel may legitimately stay unmonitorable — that is an upstream gap
  (`AstraExt/astra-monitor`), not something our config can fix.
- Adding `intel-gpu-tools` is harmless but unused by v56; it only pays off if
  upstream lands Intel support.
