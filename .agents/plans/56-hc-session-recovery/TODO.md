# TODO: Bring agent panes back after a reboot

- [x] 1. Write `common/.local/bin/hc-resume` with `snapshot`, `resume`, `--dry-run`, `--only <pane>` (D2, D4, D5).
- [x] 2. Add `common/.config/herdr-core/config.toml` with `restore_screen = true` (D1).
- [x] 3. Link both files into `~/.local/share` / `~/.config` and `~/.local/bin`; confirm the targets (D1, D6).
- [x] 4. Write `tests/hc-resume.bats` for the command builder, flag stripping, and dedupe (D7); `bats tests/hc-resume.bats` green (11/11).
- [x] 5. Add `systemd.user.timers.hc-snapshot` + `systemd.user.services.hc-resume` to `nix/configuration.nix` (D3, D6).
- [x] 6. `nix/update-nixos.sh build`, then switch. First switch failed 127 (`env bash` missing from the unit PATH); fixed with an explicit `${pkgs.bash}/bin/bash` and switched again.
- [x] 7. `hc-resume snapshot` records the claude and opencode panes; `hc-resume resume --dry-run` prints the exact per-pane commands.
- [x] 8. Probe pane: a kept terminal whose program is killed recovers to a shell, and a `resume --only` send executed its command (`/tmp/opencode/probe-ok`).
- [x] 9. Confirm `hc-snapshot.timer` is active and `hc-resume.service` exited 0 (skips the five live agent panes).
- [ ] 10. Real check after the next reboot: panes back, agents resumed on their conversations.
