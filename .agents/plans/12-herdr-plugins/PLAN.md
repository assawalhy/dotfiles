# PLAN — herdr plugins: auto-title + stay-awake configs, drop workspace-manager (#21)

## Goal
Reproducible herdr plugin setups: the auto-title and stay-awake plugins come
back from `setup-os`, their configs live in the repo, and the
workspace-manager plugin is gone.

## Findings
- The plugins did not vanish through `herdr update`: on Sep 29 `~/.config` was
  `mv`'d into `./common/.config`, link-files ran, it was moved back, and
  `git checkout common/.config` restored only *tracked* files. Plugin
  installs/registry are untracked runtime state -> lost. Nothing to recover.
- "auto title for panes and agents" = `kryptamine/herdr-auto-title`. Its config
  is `~/.config/herdr-auto-title/config.env` (read-only by the plugin).
- `assawalhy/stay-awake` persists settings through `writeJsonAtomic`
  (temp + rename), which would **replace a symlink** -> link is unsafe.
- `razajamil/herdr-plugin-workspace-manager` is the only reason
  `plugins/config/` was kept linkable; with it gone the whole `plugins/`
  dir is runtime/plugin-owned.
- herdr 0.9.1, server running, Go 1.26.7 present (auto-title builds from source).

## Decisions
- Drop workspace-manager: delete step 64 + its committed config. Rejected:
  keeping it (user asked to remove; nothing else links `plugins/config/`).
- `link-ignore.txt`: ignore `plugins/` wholesale (was `github/` + `state/`
  only). Rejected: enumerating plugin config files - the stay-awake config is
  seeded + plugin-owned, not linked.
- auto-title: track `common/.config/herdr-auto-title/config.env`, linked (the
  plugin never writes it); pin the feature defaults, leave tuning knobs
  commented. `manual-names.json` ignored (runtime).
- stay-awake: keep step 65, seed `config.json` (defaults) only when missing -
  the plugin owns and rewrites it afterwards. Rejected: symlinking it
  (`writeJsonAtomic` replaces the link -> silent desync).
- `config.toml`: add `prefix+R` -> `herdr.auto-title.restart`, matching the
  existing stay-awake key pattern.
- `herdr integration install claude` stays out of the step: it writes into
  Claude settings the dotfiles/awesome-agent own. Documented as manual.

## Milestones
1. issue #21 + epic + branch.
2. files (steps, configs, ignore, bat).
3. reinstall plugins; verify.
4. commit + PR.

## Risks
- auto-title is a young plugin (kryptamine); config path is stable but the
  plugin may add settings - pinned values keep behavior stable.
- Reinstall needs the network + a Go toolchain for the source build.
