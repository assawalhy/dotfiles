# Plan — Add swap to stop OOM kills

## Goal
Give the kernel a reclaim target so it stops OOM-killing apps (Brave) when RAM
fills up. Machine is 31 GiB RAM with **zero swap**.

## Why now (diagnosis)
- `free -h` → `Swap: 0B`. `hardware-configuration.nix` → `swapDevices = [ ]`.
- Kernel OOM killer fires repeatedly (journal, Oct 10–11), almost always on
  `brave` under `constraint=CONSTRAINT_NONE, global_oom`. Brave carries
  `oom_score_adj=300`, so it is the first casualty — that is the user's "apps
  killed".
- `systemd-oomd` logs at every boot: `No swap; memory pressure usage will be
  degraded`. systemd-oomd is **not** the killer; the kernel is.
- Memory sits at ~26/31 GiB used with Docker (postgres, minio, gotenberg) +
  several Electron/Node apps + Brave. One more browser tab or build tips it
  over and something must die — with no swap, the kernel picks.

## Approach
Two swap tiers + a swappiness tweak, declared in `nix/configuration.nix`:

```
         reclaim order
  FAST  ┌───────────────────────────┐   zram (compressed RAM)  ~16 GiB cap
 tier 1  │  zram0   priority 5       │   zstd; effective 2–3x RAM for
        └───────────────────────────┘   compressible desktop pages
  SLOW  ┌───────────────────────────┐   /var/swapfile 16 GiB, kernel default
 tier 2  │  /var/swapfile (disk)     │   priority (negative → below zram)
        └───────────────────────────┘   overflow zram can't absorb
  knob   vm.swappiness = 100             cheap reclaim while zram has room
```

## Decisions
- **D1 zram on, `memoryPercent = 50`, zstd, priority 5 (module defaults).**
  Fastest tier; browser/Electron pages are very compressible; no disk wear.
  Rejected: zram-only (compressed pages still live in RAM — a runaway or
  incompressible data still OOMs).
- **D2 Disk swapfile `/var/swapfile`, 16 GiB, default (negative) priority.**
  Real overflow for spikes; bounded to curb thrash and SSD wear; 199 GiB free
  on `/`. Rejected: swapfile-only (every page hits NVMe; no fast tier);
  dedicated swap partition (would require offline repartition of the layout,
  incl. the NTFS p4 — swapfile is equivalent, zero repartitioning).
- **D3 `vm.swappiness = 100`.** With zram first, dropping cold anonymous pages
  is cheap and prevents the kill; the kernel still prefers zram's higher
  priority. Rejected: 60 (too conservative for a zram-first box); 180
  (needlessly aggressive with a disk tier present).
- **D4 Leave `systemd-oomd` at its default.** With swap present its degraded
  mode clears; its slice-kill options stay off (turning them on would make it
  *kill* apps — the opposite of the goal).
- **D5 No hibernation.** Needs `boot.resumeDevice` + a resume offset and swap
  ≥ RAM; out of scope. Flagged, not done. (Linux `zswap` was also considered —
  zram is the modern, more flexible equivalent.)

## Milestones
1. Edit `nix/configuration.nix` (zramSwap + swapDevices + sysctl).
2. Offline validation (`nixos-rebuild build -I nixos-config=…`).
3. Deploy with `nix/update-nixos.sh` (sudo → `nixos-rebuild switch`).
4. Runtime verify + commit.

## Risks
- Swap prevents OOM only up to RAM + swap; a runaway beyond that still dies.
- Heavy swapping can thrash instead of killing; the bounded 16 GiB file and
  zram-first ordering keep that in check.
- Deploy is privileged; rollback = revert commit + `nixos-rebuild switch
  --rollback`, or just remove the block.
- First boot of the swapfile unit writes a 16 GiB file once (seconds on NVMe).

## Out of scope (separate ask)
AJQ caps every job at `MemoryMax` **and `MemorySwapMax=0`** (observed
`2 GiB`; config says `resources.memory_mb=6144`). Those jobs OOM inside their
own cgroup, where system swap cannot help. Fixing that is an ajq
config/restart concern, not swap — noted so it is not mistaken for this fix.
