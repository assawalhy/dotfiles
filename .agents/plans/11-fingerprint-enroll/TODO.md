# TODO — fingerprint enroll (06cb:00df, 104 OUT_OF_MEMORY)

Evidence trail and full write-up: `PLAN.md`.

## Diagnosis (done)

- [x] A. Full power-off + retry — user confirmed a real power-off; still 104
      (2026-10-01 02:59, 03:06). Not transient.
- [x] Rule out stale device templates — fprintd wipes the sensor DB before
      every first enrollment (`fprintd/src/device.c:2169,2228`).
- [x] F. Terminal probe `fprintd-enroll -f right-index-finger`: CLI printed
      `enroll-stage-passed` then `enroll-unknown-error`; journal 104. **The CLI
      string is a red herring** (fprintd emits it for any non-error,
      not-complete event) — corrected by H below.
- [x] H. libfprint debug trace (manual fprintd + `G_MESSAGES_DEBUG=all`,
      `/tmp/opencode/fprintd-debug.log`). Decisive: `ENROLL_READY`
      ("Place Finger on the Sensor!") → 3 ms later `Enrollment has failed!:
      104`, with no "image capture complete" and no `Enrollment is X %`. The
      sensor never takes an image. Pre-enroll sequence clean (`clear all prints
      in database` → deletion completion; identify → completion).
- [x] Ruled out MR 433 / LP#2034481 (empty-storage after BIOS reset): the guard
      *"Identify over no prints does not work for synaptics"* is present in
      libfprint 1.94.10 (`synaptics.c:788`), plus `BMKT_FP_DATABASE_EMPTY`
      handling at :736/:1089/:1166.
- [x] **KEY CONTEXT: the reader worked under Windows before the wipe+NixOS
      install** → hardware and sensor flash are proven good.

## fwupd / firmware state (done)

- [x] B. `configuration.nix`: `services.fwupd.enable = true` — parse OK.
- [x] C. Deploy: diff repo vs `/etc/nixos/configuration.nix` (only my 5 lines),
      back up, copy, `nixos-rebuild switch`. rc=0; backup
      `configuration.nix.bak-20261001-031351`; `fwupd-refresh.timer` started.
- [x] D. `fwupdmgr get-devices` — "Prometheus" (fw `10.01.3654703`) plus
      "Prometheus (IOTA Config)" (cfg `0025`), both `Updatable`.
- [x] E. `fwupdmgr refresh --force` + `get-updates` — no updates for either
      sub-device on `lvfs` **or** `lvfs-testing` (tested, then disabled).
      Not the ArchWiki buggy-fwupd case (2.1.4). fwupd#3364 also fixed here:
      the config child device enumerates.
- [x] Extra evidence: no `Failed to clear storage` warning in any boot; one
      `213 BMKT_SENSOR_STIMULUS_ERROR` (2026-09-25 03:00).
- [x] G. BIOS reader-storage reset — user did it 2026-10-01 (reboot 03:24);
      still 104.
- [x] Version comparison vs LVFS: our fw/config are both **newer** than
      anything published for PID `0xDF` (LVFS firmware `10.01.3273255`,
      release 7166; configs 5/10 for this PID, generic 21). Both came from
      HP's Windows stack.
- [x] IOTA Config `0025` understood: flash-resident data blob, its own version
      (`version` u16 + `config_id1/2` YYMMDD/HHMMSS compat key), **pinned** by
      the plugin (`version_lowest = version`, *"no downgrades are allowed"*),
      and no `&CFG1_…&CFG2_…` GUID to match an LVFS release.

## Remaining steps to try later

- [ ] K. BIOS: turn *"reset fingerprint on boot"* back **off**, review the
      other Security → fingerprint / pre-boot-auth options, reboot, retry.
      Free and reversible — do this first.
- [ ] J. Firmware downgrade test: `fwupdmgr downgrade 29ab814e…` to release
      `7166` (`10.01.3273255`, changelog *"Support Linux system"*), then retry
      enroll. **Awaiting user go.** Writes sensor firmware; `3654703` is not
      retrievable from LVFS afterwards (only via HP/Windows tooling, which is
      what flashed it originally).
- [ ] L. Cross-check under a live Windows: if Windows still enrolls, the
      fw/blob pairing is fine and Linux is behind; if Windows now fails too,
      the Windows-written fw/blob is itself inconsistent.
- [ ] M. Upstream libfprint report with the trace + version comparison, asking
      whether fw `10.01.3654703` + cfg `0025` on a `0xDF` unit is known-bad.
- [ ] N. HP service — only if L also fails.

## Closeout

- [ ] Verify: `fprintd-list assawalhy` lists the print; Settings shows it.
- [ ] Commit `configuration.nix` (`nix:`) — scoped to this change; the working
      tree also holds another session's wezterm / nix-ld edits.
