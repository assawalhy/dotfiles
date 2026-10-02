# 11 — fingerprint enroll (Synaptics 06cb:00df)

## Goal

Make `Settings → Users → Fingerprint Login` enroll a finger on the HP ZBook
Fury 15 G7 (Synaptics Prometheus `06cb:00df`).

**Status 2026-10-02: unresolved but fully characterised.** Every host-side,
BIOS and LVFS lever is exhausted; the block is on the device side and the only
remaining Linux-side lever is a reader-firmware downgrade we have not run yet.

## Diagnosis — evidence trail

### 1. Symptom

```
fprintd: Device reported an error during enroll: Enrollment failed (104)
  · 2026-09-25 02:59, 03:00 (213 once), 11:56, 21:25
  · 2026-09-28 14:25   · 2026-09-29 11:36
  · 2026-10-01 02:59, 03:06 (after power-off), 03:18, 03:26, 03:28
```

### 2. Error decode

`104 = BMKT_OUT_OF_MEMORY` — *"System ran out of memory while performing
operation"* (`libfprint/drivers/synaptics/bmkt.h:48`). Printed by
`synaptics.c:978` on `BMKT_RSP_ENROLL_FAIL`: the **sensor firmware** aborts the
enrollment. Not fprintd, polkit, PAM or the host store.

### 3. Protocol trace — the decisive evidence

Captured with a manual fprintd under `G_MESSAGES_DEBUG=all`
(log: `/tmp/opencode/fprintd-debug.log`):

```
ENROLL_USER sent
  └─► device: ENROLL_READY          ("Place Finger on the Sensor!")
        └─► 3 ms later: ENROLL_FAIL 104 OUT_OF_MEMORY
```

- **no** `Fingerprint image capture complete!`
- **no** `Enrollment is X %`

The sensor never takes an image; the finger is irrelevant. The pre-enroll
sequence is clean: `clear all prints in database` → deletion completion,
identify (duplicate check) → completion, payload
`user_id: FP1-20261001-7-47223D6D-assawalhy, finger: 1`.

> Caveat for whoever picks this up: the CLI's `Enroll result:
> enroll-stage-passed` is **not** evidence of a captured stage. fprintd emits
> that string for any non-error, not-complete event
> (`device.c:631` `enroll_result_to_name`, and explicitly at `device.c:2162`
> straight after the duplicate check).

### 4. The hardware is good

**The reader worked under Windows before the disk was wiped for NixOS.** So
the sensor, its flash and its wiring are fine — this is a Linux/device-state
interoperability problem, not a dying reader.

### 5. Device firmware / config vs LVFS

```
component            on this unit        newest on LVFS for PID 0xDF
───────────────────  ──────────────────  ────────────────────────────
reader firmware      10.01.3654703       10.01.3273255  (release 7166)
IOTA Config          0025                (generic) 21 / 0xDF-specifics 5, 10
```

Both values are **above** everything LVFS publishes for this PID — i.e. both
were written by HP's Windows stack.

- `10.01.3654703` is LVFS's version for PID **0x104**, not 0xDF.
- Release 7166's changelog is literally *"Support Linux system"*, and it is
  flagged `Is downgrade` relative to our unit.
- The IOTA Config is a versioned **data blob in the sensor flash** (not
  firmware) read via `IOTA_FIND` (cmd `0x8e`, itype `0x0009` =
  "Configuration id and version"). Its struct carries
  `config_id1` (YYMMDD) / `config_id2` (HHMMSS) / `version` (`0025` = v25) —
  the ids are a compatibility key; fwupd refuses a blob whose ids don't match
  (`"CFG version not compatible, got %u:%u expected %u:%u"`).
- The config is **pinned**: plugin comment *"no downgrades are allowed"*,
  `fu_device_set_version_lowest (self, version)`; device flag *"Only version
  upgrades are allowed"*; and our unit exposes only the
  `USB\VID_06CB&PID_00DF-cfg` GUID with **no** `&CFG1_…&CFG2_…` component, so
  no LVFS config release can match it either.

## Ruled out — with the check that ruled it out

| Suspect | Verdict | Evidence |
|---|---|---|
| PAM / polkit / fprintd | healthy | D-Bus call + auth succeed; failure is after claim |
| host print store | healthy | `fprintd-list` → 0 fingers; store path correct |
| stale device templates / DB wipe failure | clean | trace: `clear all prints in database` → deletion completion; no `Failed to clear storage` warning in any boot |
| transient device state | no | full power-off + retry still 104 |
| libfprint MR 433 / LP#2034481 (empty-storage after BIOS reset) | fix present | guard *"Identify over no prints does not work for synaptics"* at `synaptics.c:788`, `BMKT_FP_DATABASE_EMPTY` at :736/:1089/:1166 |
| fwupd#3364 (IOTA Config child hidden) | fixed | config child enumerates on fwupd 2.1.4 |
| missing firmware updates | none exist | `get-updates` empty on `lvfs` **and** `lvfs-testing` (tested, then disabled) |
| BIOS reader storage | reset done | user reset 2026-10-01, reboot 03:24; still 104 |
| dying sensor / bad flash | very unlikely | it worked under Windows |

## Open hypotheses

- **H1 — reader firmware.** HP-only `10.01.3654703` changes the enroll
  behaviour libfprint 1.94.10 expects. *Testable: downgrade to 7166.*
- **H2 — IOTA Config `0025`.** The Windows-written blob is incompatible with
  libfprint's enroll flow. **Not fixable from Linux** (pinned both up and
  down, no matching LVFS release).
- **H3 — fw/config pairing.** `3654703` is LVFS's firmware for PID `0x104`;
  our `0xDF` unit carries it. A cross-flashed pairing may be internally
  inconsistent.
- **H4 — hardware.** Effectively excluded by §4, keep only as a fallback.

## Proposed steps to try later (ordered, cheapest/most-likely first)

- **J. Firmware downgrade → retry.** `fwupdmgr downgrade 29ab814e…` to release
  `7166` (`10.01.3273255`, *"Support Linux system"*), then re-run
  `fprintd-enroll`. No version-lowest guard on the firmware device, so this
  should be permitted. **This is the one remaining Linux-side lever.**
- **K. BIOS toggle back off.** Turn *"reset fingerprint on boot"* off (a
  permanently-reset reader may be left uninitialised) and re-check the other
  Security → fingerprint / pre-boot-authentication options. Free, reversible,
  one reboot.
- **L. Cross-check under Windows.** Windows proved the hardware works; a live
  Windows (WinPE/install on the existing NTFS partition) would separate H1/H3
  from H2: windows-enrolls-fine ⇒ the blob/state is fine and Linux is behind;
  windows-also-fails ⇒ the Windows-written fw/blob itself is inconsistent.
- **M. Upstream report.** libfprint issue with the trace, `fprintd-list`,
  `fwupdmgr get-devices`, both remotes' release lists and the LVFS config
  versions — asking whether fw `10.01.3654703` + cfg `0025` on a `0xDF` unit
  is a known-bad combination. Benjamin Berg maintains the synaptics driver.
- **N. HP service.** Only if L fails on Windows too.

Then: `fprintd-list assawalhy` shows the print, Settings agrees, commit.

## Decisions

- **Keep `services.fwupd.enable = true`.** It is the tool that produced all the
  version evidence and is generally useful; on NixOS a system daemon belongs in
  `configuration.nix`, not `setup/packages.list` (system-scope managers are
  skipped there).
- **Never touch PAM / `/var/lib/fprint` / libfprint / fprintd versions.** The
  failure sits below the auth path and the device DB is already cleared per
  attempt; the host stack is current and its known device bugs are patched.
- **Do not attempt an IOTA Config downgrade.** Impossible by design (plugin
  pins `version_lowest = version`), and no LVFS release matches our CFG ids.
- **Order J after K.** K is free and reversible; J writes sensor firmware.
  (Reversed from the original plan because the user's Windows datapoint moved
  the suspicion from "host config" to "device firmware/config".)
- **Commit scope `nix:`** (matches `nix: add initial configuration.nix`,
  `nix: bump lazygit …`), scoped so the other session's wezterm / nix-ld edits
  stay untouched.

## Milestones

- fwupd installed and the device's firmware/config state established. ✅
- Enroll succeeds — **or** the blocker is classified (firmware vs config vs
  hardware) and, if upstream-worthy, reported. ⏳
- `fprintd-list` shows the print and Settings agrees. ⏳
- `configuration.nix` change committed. ⏳

## Risks

- **J writes sensor firmware.** LVFS-signed (`Trusted metadata`), 412.8 kB,
  ~2 s. `3654703` is not on LVFS for this PID, so fwupd cannot restore it —
  only HP/Windows tooling could, and it is the thing that flashed it in the
  first place, so it is probably recoverable by reinstalling Windows drivers.
- **H2 is unfixable here.** If the enrollment failure lives in the IOTA Config,
  no Linux-side action helps; say so plainly rather than implying progress.
- **Don't burn time.** If K and J fail, stop guessing and go to M/L instead of
  trying more host-side variations.

## References

- Trace: `/tmp/opencode/fprintd-debug.log`; probes `/tmp/opencode/enroll*.log`.
- Source read: `libfprint-1.94.10` (`drivers/synaptics/{synaptics.c,bmkt.h,bmkt_response.h}`),
  `fprintd-1.94.5/src/device.c`, `fwupd-2.1.4/plugins/synaptics-prometheus/`.
- [ArchWiki Laptop/HP — `06cb:00df`](https://wiki.archlinux.org/title/Laptop/HP)
- [fwupd#3364 — Synaptics prometheus can't ensure ID](https://github.com/fwupd/fwupd/issues/3364)
- [LP#2034481 — Cannot verify fingerprint if the storage is empty](https://bugs.launchpad.net/bugs/2034481) (libfprint MR 433)
- fprint list thread *"[fprint] fprint problems"* (msg01166–01170), 2021 —
  identical symptom on the same device.
- Config backup from the deploy: `/etc/nixos/configuration.nix.bak-20261001-031351`.
