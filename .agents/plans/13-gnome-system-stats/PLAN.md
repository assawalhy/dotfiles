# Plan: GNOME top-bar system stats (RAM + temperature)

## Goal
Show RAM usage and CPU temperature in the GNOME 50 top bar — the macOS-Stats
equivalent. Chosen: Astra Monitor (GNOME extension).

## Findings (verified)
- GNOME Shell 50.4 (Wayland), NixOS 26.05. hwmon here: coretemp (Package id 0,
  temp1_input = 64 °C), nvme, pch_cometlake, acpitz, iwlwifi, hp.
- Astra Monitor v56 (stable nixpkgs) declares shell-version 45..50 in its
  extensions.gnome.org zip; nixpkgs maps shell 50 → v56. Cached, 255 KiB.
- Sensors read /sys/class/hwmon directly; RAM falls back to /proc/meminfo.
  No libgtop or lm_sensors needed.
- Defaults show CPU and Memory as bars (no numbers); the sensors header is off.
  Preset: memory percentage + sensors header with the coretemp source.

## Decisions
- D1 Astra Monitor over Vitals (needs libgtop/GI_TYPELIB_PATH on NixOS),
  TopHat (no temperature), Resource Monitor (staler).
- D2 Stable v56; unstable v60 not needed.
- D3 Preset RAM % + CPU package temp only; the rest stays prefs-default.
- D4 Enable via programs.dconf profile defaults (epic 04 pattern) + one-time
  `dconf reset /org/gnome/shell/enabled-extensions` (user DB shadows them).

## Milestones
1. configuration.nix: package + enabled-extensions + astra-monitor presets.
2. Deploy /etc/nixos (timestamped backup) + nixos-rebuild switch.
3. dconf reset; load extension (re-login on Wayland if needed).
4. Verify ENABLED/ACTIVE, RAM % + temp visible, no astra journal errors.
5. Commit.

## Risks
- Wayland can't restart the Shell: re-login required; final visual check after.
- Preseeded sensor path is machine-specific; changeable in the extension prefs.
- v56 vs v60: switch to the pinned unstable if needed.
