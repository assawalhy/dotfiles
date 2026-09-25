# Plan: herdr plugin installs & runtime state out of the audit

## Goal
Stop `link-files.bash --audit` from reporting herdr's plugin installs and
runtime files as `[unlinked]`, and make the installed plugins reproducible via
`setup-os`.

## Approach
- `link-ignore.txt`: ignore herdr runtime files and the plugin install/state
  dirs; keep `plugins/config/` linkable (committed plugin config lives there).
- `setup/steps/65-herdr-stay-awake.sh`: install the stay-awake plugin from its
  upstream repo with a `check:` so re-runs skip it.
- One bats test locking in that herdr plugin/runtime files are not `[unlinked]`.

## Decisions
- Ignore `plugins/github/` + `plugins/state/` only, not all of `plugins/`:
  `plugins/config/herdr-plugin-workspace-manager/config.yml` is committed and
  must stay linked. Rejected: whole `plugins/` (would flip it to `i [ignored]`).
- Explicit file entries, no `*.log` glob: link-ignore is deliberately glob-free.
  Rejected: adding glob support to link-files (script + bats churn for one line).
- New step `65-`, not merged into `64-herdr-workspace-manager.sh`: separate
  plugin, separate check. Install unpinned, matching step 64.
- Rejected: leaving runtime files untracked (audit keeps 32 false findings).

## Milestones
1. ignore block + step + test
2. verification (bats green, audit 34 -> 2)

## Risks
- Plugin config `plugins/config/assawalhy.stay-awake/config.json` stays
  linkable and will be reported once written; intentional (track plugin config).
- The `.zshrc` conflict / `.zshrc.pre-oh-my-zsh` stale findings are unrelated
  and stay.
