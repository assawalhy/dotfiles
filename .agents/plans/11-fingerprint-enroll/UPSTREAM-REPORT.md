# Draft: libfprint issue (gitlab.freedesktop.org/libfprint/libfprint)

Not posted. Review before filing.

## Title

synaptics: 06cb:00df enroll fails with BMKT_OUT_OF_MEMORY (104) immediately after ENROLL_READY, firmware 10.01.3654703 and 10.01.3273255, IOTA config 0025

## Body

### Summary

Enrollment on a Synaptics Prometheus reader (USB 06cb:00df) always fails with `Enrollment failed (104)`.
The sensor sends `BMKT_RSP_ENROLL_FAIL` with `BMKT_OUT_OF_MEMORY` about 3 ms after `ENROLL_READY`.
No image is captured, so the finger placement is irrelevant.
The reader enrolled fine under Windows on the same machine before the disk was wiped for NixOS.

### Environment

- Laptop: HP ZBook Fury 15 G7, BIOS S92 Ver. 01.25.00
- OS: NixOS 26.05, kernel 6.18.52
- libfprint 1.94.10, fprintd 1.94.5, fwupd 2.1.4
- Device: `Bus 001 Device 005: ID 06cb:00df Synaptics, Inc.`

### Reproduction

```
fprintd-delete $USER
fprintd-enroll -f right-index-finger
```

```
Enroll result: enroll-stage-passed
Enroll result: enroll-unknown-error
```

```
fprintd: Device reported an error during enroll: Enrollment failed (104)
```

The `enroll-stage-passed` line is printed by fprintd for any non-error, non-complete event (`device.c`, `enroll_result_to_name`, and right after the duplicate check at about line 2162).
It does not mean a stage was captured.

### Protocol trace (G_MESSAGES_DEBUG=all, manual fprintd)

```
clear all prints in database  -> deletion completion
identify (duplicate check)    -> completion
ENROLL_USER sent (user_id FP1-<date>-7-<hash>-<user>, finger: 1)
  device: ENROLL_READY        ("Place Finger on the Sensor!")
  3 ms later: ENROLL_FAIL 104 BMKT_OUT_OF_MEMORY
```

Absent from the trace: `Fingerprint image capture complete!` and any `Enrollment is X %` line.
Full log of the failing enroll (43 lines, username redacted, fw `10.01.3273255`, 2026-11-13): `fprintd-debug-2026-11-13.log`, attach it to the issue.

Printed by `synaptics.c` (about line 978) on `BMKT_RSP_ENROLL_FAIL`.
Code 104 is defined in `bmkt.h` as `BMKT_OUT_OF_MEMORY`.

### Device state

Both firmware builds below fail identically.

| Component | Before | After downgrade |
|---|---|---|
| Reader firmware | 10.01.3654703 | 10.01.3273255 (LVFS release 7166) |
| IOTA Config | 0025 | 0025 |

- The firmware `10.01.3654703` and config `0025` were written by HP's Windows stack. LVFS publishes `10.01.3654703` only for PID 0x104, and nothing newer than `10.01.3273255` for PID 0xDF.
- The config device exposes only the `USB\VID_06CB&PID_00DF-cfg` GUID, with no `&CFG1_...&CFG2_...` component, and fwupd pins it (`Only version upgrades are allowed`). No LVFS config release can match it.
- The config child device enumerates, so fwupd#3364 is not the cause.

### Ruled out

- Transient device state: a full power-off and retry gave the same result.
- Stale templates: the trace shows `clear all prints in database` completing before each enroll, and there is no `Failed to clear storage` warning in any boot.
- Empty-storage identify after a BIOS reset (LP#2034481, libfprint MR 433): the guard `Identify over no prints does not work for synaptics` is present at `synaptics.c:788`.
- BIOS reader storage reset: done, still 104. "Reset fingerprint on boot" is currently off, still 104.
- Missing fwupd updates: `get-updates` is empty on `lvfs` and `lvfs-testing`.
- Host stack: PAM, polkit and fprintd are healthy. The failure is inside the device after the claim.

### Question

Is a 0xDF reader with a Windows-written IOTA config `0025` a known combination that the open synaptics driver cannot enroll?
A third-party write-up (gavdevs/elitebook840-fingerprint) claims the 0xDF and 0xF0 readers on HP business laptops need a secure, paired enroll through HP's proprietary driver, and that 104 is a generic failure code in that case.
If that is right, is there a plan to support it in libfprint, or a way to reset the sensor to a state where the open driver can enroll?

I can provide a full debug log, `fwupdmgr get-devices` output, and run test builds.
