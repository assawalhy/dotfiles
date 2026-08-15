---
slug: link-refresh-audit
status: plan-written
intent: clear
pending-action: await user's explicit start-work (or optional high-accuracy Momus review first); never self-start execution
approach: add --refresh, --audit and --no-backup to link-files.bash; --refresh captures new files that appeared inside linked dirs ($HOME) into the repo and symlinks them; --audit reports both directions (repo files not linked in home, home files not in repo) with session-context neglect (x11 neglected on wayland); --no-backup skips .bak creation under --force
---

# Draft: link-refresh-audit

## Components (topology ledger)
| id | outcome (one line) | status | evidence path |
|---|---|---|---|
| C1 --refresh | scan linked dirs under $HOME, move new real files into repo (common/ or OSDIR, mirroring existing source root), symlink them back; preview + 🔥 confirm; pattern filter; dry-run | active | .omo/evidence/task-1-link-refresh-audit.txt |
| C2 --audit | read-only report: repo files lacking a correct home link (classify new/soft/hard/stale) + real files in linked dirs absent from repo; neglect list applied per session context; exit 0 clean / 1 findings | active | .omo/evidence/task-2-link-refresh-audit.txt |
| C3 --no-backup | with --force, replace real files by rm instead of .bak.$STAMP; errors when used without --force | active | .omo/evidence/task-3-link-refresh-audit.txt |
| C4 README docs | document all three flags, the neglect mechanism, updated help text | active | .omo/evidence/task-4-link-refresh-audit.txt |

## Open assumptions (announced defaults)
| assumption | adopted default | rationale | reversible? |
|---|---|---|---|
| Refresh target root | mirror the dir's existing source root (overlay wins): if `linux/` (or `macos/`) has the dir, capture there; else `common/` | keeps per-dir provenance; git mv fixes mistakes | yes |
| Refresh scope | only dirs that are parents of ≥1 linked relpath (linked dirs); never scan $HOME root; top-level files excluded | scanning all of $HOME would capture .cache/.local junk | no (safety) |
| Refresh recursion | recurse into new subdirs under a linked dir; create repo dirs as needed | old .mjs dir listing recursed too | yes |
| Refresh vs existing repo file | relpath already in repo (write-and-rename case) = NOT a refresh candidate; goes through classify()'s existing `!` conflict path | prevents clobbering repo content | safety |
| Audit exit code | 0 = nothing to report; 1 = findings (scriptable) | grep-like convention | yes |
| --no-backup without --force | error out ("requires --force") | avoids surprise data loss | yes |
| Refresh/audit UX | no picker (batch ops), reuse pattern filter, 🔥 confirm for refresh (--yes/--dry-run work), audit is silent-read-only | consistent with existing bare-run UX | yes |
| Session detection | WAYLAND_DISPLAY set → wayland; else DISPLAY set → x11; else headless | standard; XDG_SESSION_TYPE often empty on tty-launched sessions (verified on this machine) | yes |
| Test strategy | no test framework in repo → agent-executed QA scenarios in /tmp/opencode fixture HOMEs + real-HOME read-only --audit smoke; evidence files per todo | matches previous plan's proven pattern | n/a |

## Findings (cited - path:lines)
- Current linker is per-file symlinks only: `find -type f` lister (`link-files.bash:123-141`), directory-level links refused (`in_repo_guard`, `link-files.bash:447-455`).
- Capture direction was REMOVED: `--reverse` errors with "repo is now the source of truth" and instructs a manual `mv` (`link-files.bash:87-91`).
- Backup happens in `link_one` when `$3=1`: `mv "$2" "$2.bak.$STAMP"` (`link-files.bash:462-465`); hard conflicts are `!` needing `--force` (`classify`, `link-files.bash:340-349`).
- Picker already groups `.Xmodmap`, `.xinitrc` as `x11` (`link-files.bash:277`) — natural seed for the neglect table.
- bash 3.2 constraint explicit at `link-files.bash:9-11` (no readarray/mapfile, no declare -A, no ${v,,}, no globstar).
- OLD scheme (deleted in `79a5581` "Migrate the configs to support unix systems only"): `linux-linked-files.txt` listed files AND dirs (`bin`, `.config/nvim/`, `!` negation entries) = the "linked dirs" record the user remembers; `linux-linked-files.mjs` expanded dirs recursively (`readdirSync` push); `linux-hard-link-files.bash` DEFAULT direction was capture from $HOME into repo/linux (hard links), `--reverse` pushed repo→home. Modern linker inverted this; `--refresh` restores a scoped capture.
- Live machine: `WAYLAND_DISPLAY=wayland-0` set, `DISPLAY=172.26.96.1:0`, `XDG_SESSION_TYPE` empty, session Type=tty → wayland context. `~/.Xmodmap` and `~/.xinitrc` are REAL files (not symlinks) — exactly the neglect scenario. `~/.config/nvim/` contains real files (init.lua, lazy-lock.json, .stylua.toml) not symlinked → real refresh/audit surface for read-only smoke QA.
- link-ignore.txt: exception list, entries relative to common/linux/macos, dir entry excludes subtree, no globs (`link-ignore.txt:1-14`).

## Decisions (with rationale)
- D1: `--refresh` = capture direction, scoped to linked dirs. Do NOT restore old full-$HOME capture or old `--reverse` flag.
- D2: `--audit` = read-only; never writes; exit code contract 0/1; neglect applied in both directions.
- D3: neglect mechanism = open question (in-script context table vs data-driven file) — see Open questions.
- D4: `--no-backup` only with `--force` (error otherwise); skips the .bak mv, then rm+ln proceeds.
- D5: all new code bash 3.2 safe (arrays + IFS, no mapfile/assoc).
- D6: QA never touches real $HOME for refresh/backup tests (fixtures under /tmp/opencode); real-HOME allowed ONLY for read-only `--audit` smoke with a git-status-clean guard.

## Scope IN
- link-files.bash: parse_args/help (--refresh, --audit, --no-backup), linked-dir scan + capture for refresh, audit report + neglect, link_one backup branch.
- README.md: Linking/Conflicts/Interactive sections updated.
- Evidence files under .omo/evidence/, verdicts, one commit per todo.

## Scope OUT (Must NOT have)
- No changes to setup-os / setup/ / common/ / linux/ / macos/ contents.
- No restoration of `--reverse` or the old full-$HOME hard-link capture.
- --refresh must NOT delete or overwrite any repo file (only adds new relpaths); --audit must NOT modify anything.
- No touching real $HOME in refresh/no-backup QA (fixtures only).
- No new dependencies (still pure bash 3.2 + POSIX find/awk/sed; fzf optional for the picker only).
- Do not modify .gitignore (has an intentional unstaged working-tree edit from the previous plan).

## Open questions
1. Neglect mechanism: in-script context table (recommended, minimal) vs data-driven link-context.txt (extensible) vs link-ignore.txt syntax extension. -> **USER CHOSE: data-driven link-context.txt** (2026-08-14)

## Decisions (final, user-confirmed 2026-08-14)
- D3 (RESOLVED): neglect list lives in a new repo file `link-context.txt`, format `<context>: <relpath>` per line (contexts: wayland, x11, headless; a relpath may appear on multiple lines = relevant in several contexts; comments/blank lines on their own line). Script reads it like link-ignore.txt. `--audit` neglects a file whose listed contexts do not include the current session context; files not listed are always reported.
- D7: session context detection order: `WAYLAND_DISPLAY` set → wayland (checked first, Xwayland sets DISPLAY too); elif `DISPLAY` set → x11; else headless.
- D8: test strategy = QA scenarios + evidence (user-confirmed), tests-after, agent-executed, fixtures under /tmp/opencode, read-only real-home --audit smoke allowed.

## Approval gate
status: approved (user answered the two open questions, 2026-08-14) -> write .omo/plans/link-refresh-audit.md -> DONE: plan written 2026-08-14, TL;DR filled last, 4 todos (T1 refresh / T2 audit+link-context.txt / T3 no-backup / T4 README) + final wave F1-F4, 4 commits on HEAD 92f956c.
Next gate: user's explicit start (`$start-work`); optional high-accuracy Momus review offered as one question per CLEAR route.
