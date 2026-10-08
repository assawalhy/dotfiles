# Plan — restore ranger devicons

## Goal
`default_linemode devicons` resolves again so ranger shows file icons, and the
plugin cannot silently disappear a second time.

## Findings (researched, not assumed)
- **Root cause:** `~/.config/ranger/plugins/ranger_devicons` does not exist
  anywhere under `$HOME` (searched). The dir holds only `__init__.py`. Without
  the plugin `devicons` is not in `FileSystemObject.linemode_dict`, so rc.conf's
  `default_linemode devicons` raises `Invalid linemode: devicons; should be ...`
  (ranger `config/commands.py:632-635`) — no icons at all, not wrong ones.
- **Terminal/font are fine.** WezTerm is the live terminal (`TERM_PROGRAM=WezTerm`);
  `common/.config/wezterm/wezterm.lua:16` sets
  `font_with_fallback { 'JetBrainsMono Nerd Font', ... }` and that family exists
  (`fc-list`). So this is not a tofu-box problem.
- **The plugin still works with the installed ranger** (1.9.4 / `ranger-master`,
  store `qrjq4yd…`): importing it registers `devicons` in `linemode_dict`, and
  every fsobject attribute it uses (`relative_path`, `is_directory`, `path`,
  `stat`) still exists in `container/fsobject.py`.
- **Why it vanished:** not provable from the repo, but the step's gate
  `# check: [ -d … ]` treats an *empty leftover* dir as installed. The Sep-26
  gitlink removal (`git rm --cached`) left exactly such an empty dir, so the
  clone step skipped itself. Fix the gate, not just the clone.

## Decisions
- **D1** Install via the existing `setup/steps/30-ranger-devicons.sh` — one
  source of truth for third-party ranger plugins, matching repo policy of
  installing from source.
  *(Rejected: vendoring `devicons.py` into `common/` — repo policy plus
  upstream updates lost. Rejected: nix overlay that installs the plugin into the
  ranger package — durable, but pins the plugin to a ranger rebuild and grows
  the overlay; kept as the opt-in fallback if it vanishes again.)*
- **D2** Gate the step on loadability (`__init__.py` present), not `-d`; make it
  idempotent — `git pull --ff-only` when present, wipe-and-clone when the dir is
  stale/empty. ~6 lines of bash.
- **D3** Leave `link-ignore.txt`'s `.config/ranger/plugins/ranger_devicons/`
  entry alone: it is what stops link-files from capturing the clone. The
  `plugins/` dir itself stays a real dir with only `__init__.py` symlinked.

## Milestones
1. Harden `setup/steps/30-ranger-devicons.sh`.
2. Run it → `~/.config/ranger/plugins/ranger_devicons/__init__.py` exists.
3. Verify against the real store ranger: import registers `devicons`.
4. Visual confirmation in a live ranger session (user-side).

## Risks
- `git pull --ff-only` on the shallow clone fails loudly if upstream rewrites
  history — visible error, not silent breakage.
- Wiping `$HOME` again loses the clone; nothing re-installs it automatically.
- If the user ever runs ranger in **Ghostty**: `~/.config/ghostty/config.ghostty`
  is 0 bytes and `fc-match monospace` → Noto Sans Mono (no glyphs) → icons would
  render as boxes. Separate task, only if Ghostty becomes the daily driver.