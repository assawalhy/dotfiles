# Plan — Astra Monitor built and developed locally

**Status: BUILT, NOT DEPLOYED.** Recorded 2026-11-13. The package builds and
evaluates inside the NixOS config; nothing has run in a real GNOME session yet.

## Goal
Run Astra Monitor (`monitor@astraext.github.io`, the top-bar CPU/RAM/temperature
extension) from a source build we control, so its performance and detection
problems can be fixed and tested locally. Fix the bottlenecks that can be
proven from the code.

## Findings (verified 2026-11-13 unless marked otherwise)

### The version we run is old
- nixpkgs 26.05 ships `gnomeExtensions.astra-monitor` **v56**, i.e. EGO zip
  `monitorastraext.github.io.v56`. That is upstream **release 39** (2026-03-17).
- Upstream `main` is `1343271` (2026-10-12), metadata version 62 = **release 43**.
  `RELEASES.md` for 40–43 lists fixes that match our complaints:
  - 40: GNOME Shell stutter every ~10 s with NVIDIA monitoring on, also when
    GPU stats come from the processor menu (#211). Memory management cleanup
    across menus, monitors and tasks (#225).
  - 41: menu lifecycle (stale updates, lingering loading states when switching
    menus fast); all sync file reads and probes moved to async.
  - 42: `posix_spawn()` is the default subprocess backend ("improves UI
    responsiveness when running commands"). "No GPU found" when the GPU is
    the last `lspci` block (#235). EDID crash on DisplayID blocks.
  - 43: **Intel GPU monitoring** (i915: frequency + activity out of the box;
    `intel_gpu_top` adds engines, top processes, power). GNOME 51 fix.
- The #211 thread (read 2026-11-13): the maintainer measured "a frame-time
  spike of approximately 8 ms once every 10 seconds", says release 40
  "improved the situation significantly" but does "not consider the underlying
  problem completely solved". One reporter still saw spikes after the fix.

### NixOS loads it without GTop
- `Utils.initializeGTop()` (`src/utils/utils.ts:348`) does `import('gi://GTop')`
  and sets `Utils.GTop = false` on failure. 27 call sites switch to fallbacks.
- nixpkgs' `extensionOverrides.nix` prepends `${libgtop}/lib/girepository-1.0`
  for Vitals, system-monitor and system-monitor-next, **not** for Astra Monitor.
- The gnome-shell 50.6 closure (532 paths, queried from cache.nixos.org) has no
  libgtop. Under gjs 1.88 without the path: `Typelib file for namespace 'GTop',
  version '2.0' not found`. So on this box every "Auto" data source that
  prefers GTop takes its fallback.
- GJS caches a failed `gi://` import for the process lifetime: the path must be
  prepended **before** the first import (verified in gjs; the injected code does).

### Storage header spawned two processes per tick
- Storage header is on by default (`storage-header-show` true, `storage-update`
  3 s). Without GTop, `updateStorageUsageAuto` → `updateStorageUsageProc`
  (`src/storage/storageMonitor.ts:566`), which per tick runs:
  1. `Utils.listDisksAsync()` → `lsblk -J -o ID,NAME,LABEL,MOUNTPOINTS,PATH`
     (uncached), and
  2. `lsblk -Jb -o ID,SIZE,FSUSE% <dev>`,
  then `JSON.parse`s both inside gnome-shell. That is 40 spawns a minute from
  the compositor process, forever, while the header is visible.
- Child CPU per spawn measured in this sandbox: 2.2 ms and 1.6 ms (few block
  devices; more on the laptop). Async `statfs()` through Gio from gjs:
  **58 µs**, with no fork and no JSON.
- Same function strips `_` from the device path: `/dev/mapper/x_crypt` →
  `/dev/mapper/xcrypt`, lsblk fails every tick (#237, open upstream).

### Other paths read, not changed
- NVIDIA: one long-lived `nvidia-smi -q -x -lms <gpu-update>` (2 s), full XML
  per sample, parsed in-shell with a time-sliced parser (`gpuMonitor.ts:590`,
  `:1340`). Runs only while the GPU header is shown **or a menu listens for
  `gpuUpdateProcessor`** (the processor menu). Our dconf preset keeps the GPU
  header off, so it runs only while the CPU menu is open.
- Hybrid graphics: an `nvidia-smi` loop keeps the T2000 in D0. Today the
  Samsung on DP-6 keeps it awake anyway. Undocked, it would block runtime
  suspend if `hardware.nvidia.powerManagement.finegrained` were ever enabled
  (it is not). Candidate patch (not written): skip the GPU task while
  `/sys/bus/pci/devices/0000:01:00.0/power/runtime_status` is `suspended`.
- Sensors (hwmon, our CPU temperature): per tick it only reads the selected
  attribute files. `getCachedHwmonDevices()` re-walks every hwmon dir and label
  every 5 min. Cheap; no change.
- Menus are destroyed on close and rebuilt on open (maintainer, #225 / #102):
  open-lag is by design. Without GTop, the memory top-processes list spawns
  `ps -eo pid,rss,%mem` (3 ms child CPU here) each refresh while open.
- Six monitors each own a `GLib.timeout_add` (1.5 s CPU and network, 2 s GPU,
  3 s memory/storage/sensors), so wakeups are not aligned. Untested idea:
  set CPU and network to 3 s via dconf, which roughly halves wakeups.

### Detection
- "No GPU found" was `lspci` missing (epic 25, fixed with `pciutils`). Release
  42 also fixes a last-device parse bug; whether it hit this box is unknown.
- Intel UHD 620 (i915) becomes monitorable with release 43: switch on its
  **Monitor** option in Preferences → GPU → General. `intel_gpu_top` needs
  `cap_perfmon` for engine data; the Welcome page warns if it cannot read them.
- NVIDIA temperature never shows in the Sensors panel with the proprietary
  driver: it has no hwmon device, the value only exists via `nvidia-smi` in the
  GPU panel (#146, open upstream).

## Decisions
- **D1** Build from upstream source in `nix/astra-monitor/package.nix`, pinned
  to `1343271`, instead of forking on GitHub. Same shape as copyous/todo-widget:
  the pin and patches live in this repo. A fork stays possible later: only
  `src` would change. Rejected for now: a fork (an extra repo to keep in sync
  for one patch); patching nixpkgs' v56 zip (compiled JS, and it misses 40–43).
- **D2** Transpile with `tsc --noCheck`. Upstream type-checks against the
  `@girs` npm packages, ~300 MB of dev dependencies; the emitted JS does not
  need them. `dev.sh check` runs the real type check in the working tree.
  Upstream has ~490 type errors against today's `@girs`; none in the files the
  patch touches, so the check compares only changed files.
- **D3** Inject the libgtop typelib path in `postPatch` (like nixpkgs does for
  Vitals), guarded by a grep so an upstream refactor fails the build.
- **D4** Patch 0001: cache the lsblk device list for 30 s, read usage with
  Gio's async `statfs()` on the mountpoint (lsblk only as fallback), keep `_` in
  device paths. With GTop wired in, the GTop path is taken first anyway, so the
  patch matters for any setup without GTop and is upstreamable on its own.
- **D5** Local development via `nix/astra-monitor/dev.sh`: working tree at
  `~/Projects/astra-monitor` (branch `local` = pinned rev + patches as commits);
  `nested` runs the dev build in a nested shell with a throwaway
  `XDG_DATA_HOME`, so it never shadows the system copy in the real session
  (the copyous trap from epic 41); `export` writes the commits back to
  `patches/`; `bench` A/B-measures gnome-shell CPU with the extension on vs off.
- **D6** No dconf changes yet (intervals, Intel GPU toggle). Measure first.

## Milestones
1. Baseline on the current system (release 39): `dev.sh bench 60`.
2. `nix/update-nixos.sh`, re-login (the Shell keeps loaded extension code).
3. `dev.sh bench 60` again; compare shell and children CPU.
4. Confirm GTop: Preferences → Utility shows libgtop as available; the
   storage header shows usage; `dev.sh log` stays quiet.
5. Enable the Intel GPU in Preferences → GPU; decide on Main GPU (epic 25 D3).
6. Optional: offer patch 0001 upstream (#237 plus the lsblk-per-tick cost).

## Risks
- Release 43 is 4 releases newer: new code paths (Intel GPU, posix_spawn) have
  limited upstream testing. Fallback: Preferences → Utility → Legacy Subprocess,
  or point the binding back at `gnomeExtensions.astra-monitor`.
- `--noCheck` builds would not catch a type error in a patch; run `dev.sh check`
  before exporting.
- GNOME 50's nested mode is `gnome-shell --devkit` (49+). `dev.sh nested` has
  not been run on the laptop yet.
