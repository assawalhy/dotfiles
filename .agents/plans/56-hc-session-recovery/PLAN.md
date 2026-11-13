# Plan: Bring agent panes back after a reboot

## Goal

After a reboot every Herdr pane returns as it was: same address and cwd, the last
screen above a fresh shell, and the agent that lived there restarted on its own
conversation.

## What is already true

- Recovery is a core feature. On core start every kept terminal gets a fresh shell
  in its saved cwd, same address, and the app layout still maps to it. This boot:
  core started 09:46:02, 13 panes re-spawned at 09:46, 11 spaces restored.
- Doubly confirmed by the CLI help: `server stop` "parks kept terminals; next core
  start gives them shells".
- It never re-runs the program, and `restore_screen` defaults to false, so the old
  screen is discarded instead of shown. That is the whole gap the user hit.
- `hc get <pane>` reports `foreground.name` and `foreground.argv` while an agent
  runs. After recovery only the shell is there, so the lost program must be
  recorded before the reboot.
- `Linger=yes` for the user, so user units run at boot without a login.
- Available: hc 0.1.21, claude 2.1.323 (`-c/--continue`, `--resume <id>`),
  opencode 2.1.4 (`-c/--continue`, `-s/--session <id>`), codex 0.166.0
  (`resume --last`), jq and python3 in the system profile.

## Approach

```
 boot
  └─ user default.target
      └─ hc-resume.service (oneshot)
           hc server start                    core recovers kept terminals
           read ~/.local/state/hc-resume/state.json
           per pane whose last foreground was an agent:
             wait until live with a shell (max 60 s)
             hc send <addr> "<argv> --continue"
 every 20 s
  └─ hc-resume.timer
      └─ hc-resume snapshot                  pgrep core first, then hc get per pane
                                             -> ~/.local/state/hc-resume/state.json
```

Plus `restore_screen = true`, so the dead program's screen sits above the new shell.

## Decisions

### D1 `restore_screen = true` in a linked config

`common/.config/herdr-core/config.toml`, symlinked by `link-files`. Three lines,
native, and it also keeps the old output in `hc read` after the rebound.
Rejected: leaving it false — that is the behaviour being fixed.

### D2 Snapshot by polling timer

Every 20 s, `hc ls` then `hc get` per live pane, write `state.json` atomically
(tmp + `mv`). `pgrep -f herdr-core serve` first, so the timer never starts a core.
Rejected: `hc events` stream (needs a warm map and a long-lived daemon for one
file), a shutdown hook (systemd kills user units in no fixed order relative to the
core), and scraping restored screens (TUI text is far less reliable than `hc get`).

### D3 Start the core at boot from the resume unit

`hc server start` is idempotent, so it works whether the app got there first or not.
Rejected: waiting for the app, which leaves no recovery when the app was closed at
shutdown. This is the autostart unit plan 53 D5 deferred, now with a reason to exist.

### D4 Resume command = recorded argv + the CLI's own flag

`<bin> <original flags> --continue`, with any existing `-c/--continue/--resume`
stripped first. Codex is special-cased to `<bin> resume --last`. The binary is
resolved with an explicit PATH (`~/.local/bin`, `~/.opencode/bin`, system profile)
inside the script. Rejected: bare `claude --continue`, which drops flags such as
`--dangerously-skip-permissions`; `/proc/<pid>/exe`, which points at the versioned
binary (`~/.local/share/claude/versions/2.1.323`) and breaks on self-update.

### D5 Skip conditions

Skip a pane that is not `live`, whose current foreground is not a shell, whose
snapshot cwd no longer matches, that carries `hc.resume=no`, or whose
(agent, cwd) pair was already resumed. Duplicates are logged, not typed twice.
Rejected: resuming every match blindly — two panes on one conversation, or typing
over a command you already started.

### D6 Script in dotfiles, units in Nix, state in `~/.local/state`

`common/.local/bin/hc-resume` (bash + jq) is symlinked, so the logic changes without
a rebuild; the two units live in `nix/configuration.nix`; runtime state stays out of
the repo. Rejected: a `setup/steps` installer owning the units — system config
belongs in the NixOS config, as with the flatpak timer.

### D7 Tests for the command builder

`tests/hc-resume.bats` extracts the pure functions (`resume_command`, dedupe,
flag stripping) the same way `tests/montag.bats` does. No core, no network.

## Milestones

1. Script, config file, links.
2. Tests green.
3. Units, rebuild, switch.
4. Live proof on a probe pane; the real proof is the next reboot.

## Risks

- `hc get`'s JSON is not a published contract. A core update can rename a field;
  tolerant jq plus a log line make that visible instead of silent.
- `--continue` resumes the most recent conversation for that cwd, not necessarily
  the exact one. Two agents in one cwd is the failure case, handled by D5.
- A power cut saves no screen, so the pane comes back with no old text. The agent
  still resumes.
- An agent can stop at a trust or login prompt; the pane is then waiting for you,
  which is still better than a bare shell.
- The core started at boot has no desktop session, so recovered shells have no
  `SSH_AUTH_SOCK` until your shell's own agent setup runs. Same as any boot-time
  service; noted, not fixed here.
