# link-refresh-audit - Work Plan

## TL;DR (For humans)
<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** Three new options for the dotfile-linking script. One brings new config files that programs have created inside linked folders (like the nvim config folder) back into the repo and re-links them in place. Another is a read-only health check that lists links that have drifted and configs that exist on the machine but are missing from the repo — and it is smart about your display server, so it won't nag you about X11-only files on a Wayland machine. The third lets the "force" option delete an old real file instead of keeping a `.bak` copy when replacing it with a link.

**Why this approach:** The script today only links the repo out to the home folder; programs keep writing their own files, so the two sides drift apart. A one-way capture plus a checkable report closes the loop, a plain-text "don't nag about these on this context" list keeps the rules data-driven (no code changes to add a new rule), and every test runs on throwaway copies so your real configs are never at risk.

**What it will NOT do:** It will not bring back the old auto-capture of the whole home folder (that was deliberately removed years ago), will not delete or overwrite anything already in the repo, will not change any of the config files themselves, and will not touch your real home folder during testing.

**Effort:** Four small steps — the script changes, a new plain-text list, and the docs — done as four commits, each verified by runnable checks.

**Risk:** Low. The script is self-contained, all destructive tests run on copied fixtures under a scratch folder, the health check is strictly read-only, and a failed move rolls itself back so a file is never stranded.

**Decisions to sanity-check:** (1) The "don't nag" list lives in a new plain-text file with lines like `x11: .Xmodmap`. (2) The health check reports findings with exit code 1 (0 means clean). (3) The no-backup option is destructive by design: it deletes the old file instead of keeping a backup.

Your next move: tell me to start the work, or ask for a full review of the plan first. Full execution detail follows below.

---

> TL;DR (machine): add `--refresh` (capture new real files inside linked dirs into repo + symlink back, mirror-root, rollback on ln failure), `--audit` (read-only drift report both directions, wayland/x11/headless session neglect via new `link-context.txt`, exit 0 clean / 1 findings), `--no-backup` (rm instead of `.bak` under `--force`, refuses dirs, errors without `--force`) to `link-files.bash` + README; 4 todos + final F1-F4 wave, 4 commits on HEAD 92f956c, bash-3.2-safe, QA in /tmp/opencode fixtures only.

## Scope
### Must have
- `link-files.bash` gains three flags: `--refresh`, `--audit`, `--no-backup` (parse_args + help text, `link-files.bash:42-104`).
- New data file `link-context.txt` (repo root, next to `link-ignore.txt`): the `--audit` context-neglect list, data-driven, format `<context>: <relpath>` per line.
- `--refresh`: capture direction restored, scoped to linked dirs. New real files (not symlinks, not in repo, not in link-ignore.txt, not gitignored) inside linked dirs under `$HOME` are moved into the repo (mirroring the dir's source root: OS overlay if the dir exists there, else `common/`) and symlinked back. Recurses into new subdirs. Preview + 🔥 confirm; `--dry-run`/`--yes`/pattern filter work. Never touches existing repo files; never resolves conflicts; never deletes anything it did not move.
- `--audit`: read-only report of (a) repo files lacking a correct home link (reusing classify/find_stale: missing/relink/conflict/stale) and (b) real files in linked dirs absent from the repo (the `--refresh` candidates). Applies the context-neglect list from `link-context.txt`. Exit `0` = nothing to report, `1` = findings. Never writes, no picker, no prompt.
- `--no-backup`: with `--force`, replaces a conflicting real file with `rm` instead of `.bak.$STAMP`; errors (exit 1) when used without `--force`; refuses (exit 1) when the conflict target is a directory.
- Session-context detection for `--audit`: `WAYLAND_DISPLAY` set → wayland (checked first — Xwayland sets DISPLAY too); elif `DISPLAY` set → x11; else headless.
- README.md documents all three flags, the neglect mechanism, and updated help text.
- One commit per todo; evidence files under `.omo/evidence/task-<N>-link-refresh-audit.txt`.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No changes to `setup-os`, `setup/`, `common/`, `linux/`, `macos/` contents.
- No restoration of `--reverse` or the old full-`$HOME` hard-link capture (`link-files.bash:87-91` semantics stay).
- `--refresh` MUST NOT delete or overwrite any existing repo file; it only adds new relpaths. If `ln` fails after `mv`, the file is moved back (rollback) and the script exits nonzero.
- `--audit` MUST NOT modify anything (repo or `$HOME`); proof of read-only is part of QA.
- QA for refresh/backup runs only in fixture HOMEs under `/tmp/opencode` — the real `$HOME` is touched only by the read-only `--audit` smoke in the final wave, with a git-state guard.
- All new code bash 3.2 compatible (no `readarray`/`mapfile`, no `declare -A`, no `${v,,}`, no globstar, no `sort -V`, no `find -mindepth`) and `set -e`-safe (every grep/find pipeline guarded like `link-files.bash:157` and `:367-368`).
- No new dependencies beyond what the repo already requires (bash, find, awk, sed, sort, git — `git check-ignore --no-index` for the gitignore filter; fzf stays optional for the picker only).
- Do not `git add .gitignore` (its staged + unstaged states differ deliberately; see commit strategy) and do not commit `.codegraph/` or `.claude/`.
- link-context.txt stays a flat relpath list — no globs, no dir/subtree semantics, no second `link-ignore.txt`.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after + agent-executed QA scenarios (user-confirmed). No test framework exists in this repo; fixtures + evidence files follow the proven pattern of the previous plan.
- Evidence: `.omo/evidence/task-<N>-link-refresh-audit.txt` per todo, plus the shared `.omo/notepads/link-refresh-audit/` notepads and `.omo/start-work/ledger.jsonl` entries (append-only, one JSON line per event).
- Every todo's QA includes: `bash -n link-files.bash` + a syntax scan of the diff for forbidden bash-5.2-only constructs (`<<<`, `mapfile`, `readarray`, `declare -A`, `${v,,}`, `globstar`, `sort -V`, `find -mindepth`) — the compat gate cannot rely on the dev machine's bash 5.2.
- Fixture recipe (each todo rebuilds as needed): `rm -rf /tmp/opencode/fx-repo /tmp/opencode/fx-home && mkdir -p ...`; fixture repo = `cp -r` of `link-files.bash link-ignore.txt link-context.txt .gitignore common linux macos` into `/tmp/opencode/fx-repo` (no `.git`); fixture home = hand-built tree with a mix of correct symlinks, new real files, conflicts, stale links. Run the fixture's own `link-files.bash` with `HOME=/tmp/opencode/fx-home` so `REPO` resolves to the fixture (script derives REPO from its own location, `link-files.bash:29-35`).

## Execution strategy
### Parallel execution waves
- Wave 1: T1 (`--refresh`).
- Wave 2: T2 (`--audit` + `link-context.txt` + session detection).
- Wave 3: T3 (`--no-backup`).
- Wave 4: T4 (README docs).
- Final wave: F1-F4 in parallel.
- All of T1-T3 edit `link-files.bash` (same file → serialize). T4 (README) depends on the final CLI/help text from T1-T3.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 --refresh | — | 2, 3, 4 | — (same file) |
| 2 --audit | 1 (same-file discipline, not logic) | 3, 4 | — (same file) |
| 3 --no-backup | 2 | 4 | — (same file) |
| 4 README | 1, 2, 3 | — | — (different file, but needs final help text) |

## Todos
> Implementation + Test = ONE todo. Never separate.

- [x] 1. `link-files.bash`: add `--refresh` — capture new files that appeared inside linked dirs into the repo and symlink them back
  What to do:
  - CLI: add `--refresh` to `parse_args` (`link-files.bash:80-104`) as `is_refresh=1`; add it to `print_help` USAGE + OPTIONS (`:46-77`).
  - Picker bypass: extend the `main()` picker condition (`:501`) so `--refresh` (and later `--audit`) never opens the picker: `if [ -z "$is_dry" ] && [ -z "$is_yes" ] && [ -z "$pattern_given" ] && [ -z "$is_refresh" ] && [ -z "$is_audit" ]; then picker; fi`.
  - New function `refresh_scan()`: derives linked dirs from the already-built `$merged` list (`<root>\t<rel>` lines, `:158-159`) — for every rel containing `/`, take `dirname`; the set of unique dirnames = linked dirs. Map to `$HOME/<dir>`. Top-level rels (no `/`) are skipped: their parent is `$HOME` itself and `$HOME` is never scanned. For each linked dir D that exists and is NOT a symlink (guard: `[ -L "$D" ] && continue`): `find "$D" -type f` (real files only; `find -type f` already skips symlinks; don't follow symlinked subdirs — plain `find` does not follow them) excluding:
    - relpaths already in the repo's merged rel set (managed or conflict → skip silently; conflicts stay with the normal flow),
    - relpaths matched by `link-ignore.txt` (reuse the ignore-set logic of `read_ignores`/`list_root`, `:114-141`),
    - relpaths gitignored: `git -C "$REPO" check-ignore --no-index -q -- "$rel" && continue` (works without a `.git` dir in fixture repos; `.gitignore` is copied into fixtures),
    - any path under a `.git` directory or a symlinked subdir,
    - `.bak.$STAMP`-style files (`*.bak.*`).
    Emit candidates as `<rel>\t<home-abs-path>\t<repo-dest-abs-path>`.
  - Mirror-root rule (decision D1): for candidate rel R with dir D=`dirname(R)`: if `[ -d "$OSDIR/$D" ]` → repo dest = `$OSDIR/$R`; elif `[ -d "$COMMON/$D" ]` → dest = `$COMMON/$R`; else → dest = `$COMMON/$R` (new dir; `mkdir -p` the repo side). Note: `bin` exists in both `common/` and `linux/` → OSDIR wins per overlay rule (matches the old scheme's linux-targeting).
  - Preview + confirm: reuse the preview/confirm UX pattern (`:406-440`) — print `+  <rel>  [refresh -> common|linux|macos]` lines; `--dry-run` prints then exits 0; `--yes` skips the prompt; otherwise the 🔥 `[y/N]` prompt, any non-yes exits 1. Pattern filter (`$filter`, `:103`) narrows candidates.
  - Apply per candidate: `mkdir -p "$(dirname "$repo_dest")"`; `mv "$home_abs" "$repo_dest"`; `ln -s "$repo_dest" "$home_abs"`. **Rollback (Metis M5):** if `ln` fails, `mv "$repo_dest" "$home_abs"` back and exit 1 with the error — a user file must never be left only in the repo. Print `-> mv + ln -s <rel>` per file.
  - `--force`/`--no-backup` have NO effect on `--refresh` (capture-only; conflicts in scanned dirs are skipped, not resolved).
  Must NOT do: restore `--reverse`; scan `$HOME` root or top-level files; touch existing repo files; resolve conflicts; delete stale links; follow symlinked subdirs; capture gitignored or ignored relpaths; leave a moved file without its symlink on failure.
  Parallelization: Wave 1 | Blocked by: — | Blocks: 2, 3, 4
  References (executor has NO interview context - be exhaustive):
  - `link-files.bash` (whole file, 507 lines): parse_args `:80-104`, print_help `:46-77`, read_ignores `:114-120`, list_root `:123-141`, collect `:143-171`, picker skip `:501`, classify `:319-354`, find_stale `:360-375`, preview `:387-404`, confirm `:406-440`, link_one `:457-471`, main `:496-507`. Bash 3.2 constraint `:9-11`. `set -e` guard idioms `:157`, `:367-368`.
  - `link-ignore.txt` (repo root): the existing exception-list format to mirror.
  - `.gitignore` (repo root): contains `__pycache__/`, `*.pyc`, `.vscode/`, `.claude/` — refresh MUST honor it (`git check-ignore --no-index`).
  - Historical basis (do NOT copy, just understand): `git show 79a5581^:linux-hard-link-files.bash` — old default direction captured $HOME→repo; `git show 79a5581^:linux-linked-files.mjs` — dir recursion precedent.
  - Live reality: real candidates on this machine are `~/.config/nvim/lua/plugins/kotlin.lua` (not in repo) and junk that MUST be excluded (`~/.config/ranger/plugins/__pycache__/`, `~/bin/.vscode/launch.json`); the repo files at `~/.config/nvim/init.lua` etc. are CONFLICTS, not candidates (Metis C1/U3).
  Acceptance criteria (agent-executable):
  - `bash -n /tmp/opencode/fx-repo/link-files.bash` passes; diff syntax-scan for forbidden constructs is clean.
  - Fixture: `fx-home/.config/nvim/` = one correct symlink (→ `fx-repo/common/.config/nvim/init.lua`) + one new real file `newfile.lua` + one new subdir `lua/extra.lua`; `fx-home/.config/nvim/__pycache__/junk.pyc` (gitignored) + `fx-home/.config/nvim/skip.me` in link-ignore. `HOME=/tmp/opencode/fx-home ./link-files.bash --refresh --dry-run` prints `+  .config/nvim/newfile.lua [refresh]` and `+  .config/nvim/lua/extra.lua [refresh]`; prints NOTHING for `__pycache__/junk.pyc` or `skip.me`; creates no files (sentinel `find` clean); exit 0.
  - `HOME=/tmp/opencode/fx-home ./link-files.bash --refresh --yes`: `fx-repo/common/.config/nvim/newfile.lua` and `fx-repo/common/.config/nvim/lua/extra.lua` exist; `fx-home/.config/nvim/newfile.lua` is a symlink whose `readlink` == the fx-repo path; originals gone from fx-home; `init.lua` symlink untouched; `__pycache__/junk.pyc` and `skip.me` still real files; exit 0.
  - Overlay-mirror fixture: `fx-repo/linux/.config/shell/` exists (from `cp -r linux`) → a new real file `fx-home/.config/shell/new.sh` is captured into `fx-repo/linux/.config/shell/new.sh` (not common).
  - Pattern filter: `--refresh '\.lua$' --dry-run` lists only the `.lua` candidates.
  - Confirm prompt: `printf 'n\n' | HOME=... ./link-files.bash --refresh` exits 1 and moves nothing.
  QA scenarios (name the exact tool + invocation): happy = the fixture commands above; failure = (a) `ln` failure rollback: make `fx-home/.config/nvim` read-only after `mv` (or stub `ln`) and assert the file is moved BACK and exit is 1; (b) `--refresh` on a relpath that already exists in the repo (write-and-rename case: real file at `fx-home/.config/nvim/init.lua`) → skipped, not captured, no repo modification. Evidence: `.omo/evidence/task-1-link-refresh-audit.txt` (all commands + outputs + `git status --short` of fx-repo).
  Commit: Y | `link-files: add --refresh to capture new files in linked dirs`

- [x] 2. `link-files.bash` + `link-context.txt`: add `--audit` — read-only link-drift report with session-context neglect
  What to do:
  - New file `link-context.txt` at repo root, format (mirror `link-ignore.txt` style):
    ```
    # Context-neglect list for --audit. Each line: <context>: <relpath>
    # Contexts: wayland, x11, headless. A relpath may appear on multiple
    # lines (relevant in several contexts). Comments/blank lines on their own
    # line. No globs. Relpath is relative to common/, linux/ or macos/.
    x11: .Xmodmap
    x11: .xinitrc
    ```
  - Session detection function `session_context()`: `[ -n "$WAYLAND_DISPLAY" ]` → print `wayland`; elif `[ -n "$DISPLAY" ]` → print `x11`; else print `headless`. (Order matters: Xwayland sets both; this machine has `WAYLAND_DISPLAY=wayland-0` → wayland.)
  - Context reader `read_contexts()` mirroring `read_ignores` (`:114-120`): parse `link-context.txt` with `sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d'` into a temp file `$CTX_TMP` (add to the `collect` trap list `:148`). Malformed lines (no `: `) are ignored. Missing file = empty neglect (no error), exactly like `read_ignores` treats a missing `link-ignore.txt` (`:116`).
  - Neglect predicate `neglected()` (decision D3, pinned — Metis M7): relpath R is neglected iff `$CTX_TMP` contains ≥1 line `<ctx>: R` AND `session_context()` is not among those `<ctx>` values. Unlisted R → never neglected. Both directions (a) and (b) apply the predicate.
  - `--audit` flow: run the normal `collect`/`classify`/`find_stale` machinery (read-only; `:143-375`) plus a direction-(b) scan (reuse `refresh_scan()` candidate emission from T1 without applying). Report, in the existing marker style (`:387-404`):
    - `-  stale` links (existing `stale` array),
    - `+  <rel> [missing]` for repo files not linked in home (`new_rel`),
    - `*  <rel> [relink]` for `soft_rel`,
    - `!  <rel> [conflict]` for `hard_rel`,
    - `+  <rel> [unlinked]` for direction-(b) candidates (refresh candidates),
    - a one-line context header: `audit context: wayland (neglecting: x11: .Xmodmap, x11: .xinitrc)`.
    Suppress any line whose rel is neglected. Pattern filter (`$filter`) narrows the report.
  - Exit contract: 0 = nothing to report (after neglect); 1 = any reported finding. Print a final summary line: `Audit clean (N links correct, M neglected).` or `Audit findings: K.` Never prompts, never writes, never opens the picker (picker bypass added in T1 covers `is_audit`).
  - CLI: add `--audit` to `parse_args` + `print_help`.
  Must NOT do: modify anything (repo or $HOME); prompt or confirm; follow symlinks; report neglected relpaths; treat a missing `link-context.txt` as an error; exit nonzero for a clean audit.
  Parallelization: Wave 2 | Blocked by: 1 | Blocks: 3, 4
  References (executor has NO interview context - be exhaustive):
  - `link-files.bash`: collect/merged `:143-171`, classify arrays `:312-354`, find_stale `:360-375`, preview marker style `:387-404`, confirm/exit patterns `:406-440`, read_ignores idiom `:114-120`, trap list `:148`, main `:496-507`.
  - `link-ignore.txt`: the file format precedent for `link-context.txt`.
  - Live machine: `WAYLAND_DISPLAY=wayland-0` (wayland), `~/.Xmodmap` + `~/.xinitrc` are REAL files → under wayland, `--audit` must NOT report them (they are in the neglect list); under an x11 session they WOULD be reported.
  - Metis M7 pin: predicate examples — wayland session + `x11: .Xmodmap` → neglected; x11 session → reported; unlisted file → always reported; `wayland: X` + `x11: X` → reported in both sessions.
  Acceptance criteria (agent-executable):
  - Fixture: fx-home with a correct symlink, a missing link (repo file, no home entry), a stale link (symlink → fx-repo path whose source was deleted from fx-repo), a foreign symlink, a conflict (real file at a repo relpath), one unlinked new file (direction b), plus `fx-home/.Xmodmap` as a REAL file and `link-context.txt` with `x11: .Xmodmap`.
  - `WAYLAND_DISPLAY=wayland-0 DISPLAY= ./link-files.bash --audit; echo $?` → reports missing/stale/foreign/conflict/unlinked; does NOT report `.Xmodmap`; exit 1.
  - `WAYLAND_DISPLAY= DISPLAY=:0 ./link-files.bash --audit` → reports `.Xmodmap` (x11 session); exit 1.
  - `WAYLAND_DISPLAY= DISPLAY= ./link-files.bash --audit` (headless) → `.Xmodmap` neglected; exit 1.
  - Read-only proof: `touch` a sentinel file in fx-repo and fx-home; run `--audit`; `find /tmp/opencode/fx-repo /tmp/opencode/fx-home -newer <sentinel>` is empty; symlink states unchanged.
  - Clean audit: fix every finding in a second fixture (all correct); `--audit` prints `Audit clean`, exit 0.
  - Missing `link-context.txt`: remove it from fx-repo; `--audit` still works, reports `.Xmodmap`, exit 1 (no error).
  - Malformed line: add `garbage-line` (no colon) → ignored, audit still runs.
  QA scenarios (name the exact tool + invocation): happy = env-var matrix runs above (export/unset `WAYLAND_DISPLAY`/`DISPLAY` per row); failure = (a) read-only violation (sentinel `find -newer`), (b) exit-code contract (`echo $?` after each run), (c) neglect inversion guard — assert `.Xmodmap` is reported under x11 but not wayland (proves the predicate is not double-negated). Evidence: `.omo/evidence/task-2-link-refresh-audit.txt`.
  Commit: Y | `link-files: add --audit link-drift report with context neglect` (+ new file `link-context.txt` in the same commit)

- [x] 3. `link-files.bash`: add `--no-backup` — skip `.bak.$STAMP` creation under `--force`
  What to do:
  - CLI: `--no-backup` in `parse_args` → `is_no_backup=1`; add to `print_help`. If `is_no_backup` and NOT `is_force`: `printf 'error: --no-backup requires --force\n' >&2; exit 1` (decision D4, Metis M3-adjacent).
  - `link_one()` (`:457-471`): in the backup branch (`$3 = 1 && [ -e "$2" ] && [ ! -L "$2" ]`, `:462`):
    - if `[ -d "$2" ]` → refuse: `printf 'error: --no-backup cannot replace a directory (%s); run --force without --no-backup or remove it manually\n' "$2" >&2; exit 1` (Metis M4 — plain `rm -f` fails on a dir and would abort mid-apply under `set -e`).
    - elif `is_no_backup` → print `-> rm (no backup) <file>` and `rm -f "$2"` instead of the `mv` to `.bak.$STAMP`.
    - else → existing behavior unchanged.
  - The `rm -f "$2"` before `ln -s` (`:469`) already handles the rest; no other changes to `apply`.
  Must NOT do: change behavior of `--force` without `--no-backup`; remove the backup logic; touch directories under `--no-backup`; allow `--no-backup` without `--force`; affect `--refresh` or `--audit`.
  Parallelization: Wave 3 | Blocked by: 2 | Blocks: 4
  References (executor has NO interview context - be exhaustive):
  - `link-files.bash`: parse_args `:80-104`, print_help `:46-77`, classify hard branch `:340-349` (where `$3=1` originates), link_one `:457-471` (backup mv at `:462-465`, rm+ln at `:466-470`), apply `:473-494`, main `:496-507`. `set -e` note `:14`.
  - README "Conflicts" section: "Real files are never deleted. Under --force they are moved to <file>.bak.<timestamp> first." — will be amended by T4.
  Acceptance criteria (agent-executable):
  - Fixture: fx-home has a REAL file at a repo relpath (e.g. `fx-home/.config/mpv/mpv.conf`, which exists in `common/`). `HOME=... ./link-files.bash --force --no-backup --yes` (narrow with pattern `mpv.conf`) → file replaced by symlink; `ls fx-home/.config/mpv/` shows NO `.bak.*` file; exit 0.
  - Same fixture without `--no-backup`: `--force --yes` → `.bak.<STAMP>` exists; exit 0.
  - `./link-files.bash --no-backup` (no `--force`) → `error: --no-backup requires --force`, exit 1, nothing changed.
  - Directory conflict: fx-home has a REAL DIRECTORY at a repo relpath (e.g. `fx-home/.config/nvim` as a real dir with files, no symlink) → `--force --no-backup` refuses with the dir error, exit 1, directory intact, no partial apply.
  QA scenarios (name the exact tool + invocation): happy = the two `--force` runs above with `ls` assertions; failure = the two error paths (exit codes + `find fx-home -name '*.bak.*'` empty in the no-backup case). Evidence: `.omo/evidence/task-3-link-refresh-audit.txt`.
  Commit: Y | `link-files: add --no-backup to skip .bak under --force`

- [x] 4. `README.md`: document `--refresh`, `--audit` and `--no-backup`
  What to do:
  - In the "Linking" section (usage block): add the three flags to the USAGE/OPTIONS listing.
  - New subsection under "Linking": "Capturing new files (`--refresh`)" — plain explanation: run after programs created files inside linked dirs; what gets captured (new real files not in repo/ignore/gitignore), where they land (mirror rule), the 🔥 confirm, `--dry-run`/`--yes`/pattern, and that it never overwrites repo files.
  - New subsection: "Checking the link state (`--audit`)" — read-only, both directions, exit 0/1 contract, session contexts (wayland/x11/headless) and the `link-context.txt` neglect list with the `x11: .Xmodmap` example.
  - Amend the "Conflicts" paragraph "Real files are never deleted. Under --force they are moved to <file>.bak.<timestamp> first." → add: "…unless `--no-backup` is given, which deletes the real file instead (and refuses directory conflicts)."
  - Document `link-context.txt` in the repo layout/preview area next to `link-ignore.txt`.
  - Keep the "no longer needs node" and layout claims intact; do not change any other section.
  Must NOT do: restructure unrelated README sections; remove the `--reverse` removal note (`:87-91` still errors); document flags that do not exist.
  Parallelization: Wave 4 | Blocked by: 1, 2, 3 | Blocks: —
  References (executor has NO interview context - be exhaustive):
  - `README.md`: "Linking" usage block, "Interactive selection", "What gets linked", "Conflicts" section ("Real files are never deleted…"), "Installing programs" area is untouched.
  - `link-files.bash:46-77` (final help text after T1-T3 — the README must match it verbatim).
  Acceptance criteria (agent-executable):
  - `grep -c -- '--refresh' README.md` ≥ 3; `grep -c -- '--audit' README.md` ≥ 3; `grep -c -- '--no-backup' README.md` ≥ 2.
  - `grep -q 'link-context.txt' README.md`; `grep -q 'no-backup' README.md` (in the Conflicts paragraph context).
  - Code fences balanced: count of ``` lines in README.md is even.
  - `./link-files.bash --help | grep -q -- '--refresh'` and same for `--audit` and `--no-backup` (help text and README agree).
  QA scenarios (name the exact tool + invocation): happy = the greps above + `npx markdownlint-cli2 README.md 2>/dev/null || true` (informational only, no markdownlint installed — do not fail on it); failure = fence-balance check (odd count → fix). Evidence: `.omo/evidence/task-4-link-refresh-audit.txt`.
  Commit: Y | `README: document --refresh, --audit and --no-backup`

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit - check every todo: all 4 done with evidence files present. Re-run the acceptance greps/commands per todo against the committed state (fixture commands from each todo's QA). `bash -n link-files.bash` clean. `--help` shows all three flags.
- [x] F2. Code quality review - grep the diff (`git diff <base>..HEAD`; base = the commit before T1) for bash 3.2 violations (`<<<`, `mapfile`, `readarray`, `declare -A`, `${v,,}`, `sort -V`, `find -mindepth`, globstar) and for dead code (leftover `--reverse` behavior, unreferenced new functions). Check `link-files.bash`, `link-context.txt`, `README.md` all pass `bash -n` / are syntactically valid on the committed state.
- [x] F3. Real manual QA - tmux-free, fixture-driven, PLUS the read-only real-home smoke: build fresh fixtures per the todo recipes and run `--refresh`, `--audit` (all three session contexts via env), `--no-backup` end-to-end; then `./link-files.bash --audit` against the REAL repo + REAL `$HOME` with the git-state guard: `git status --short` before/after identical (must stay `MM .gitignore` + `?? .omo/` + committed work) — assert exit 1 (findings exist: real conflicts are expected on this machine), `.Xmodmap`/`.xinitrc` NOT reported (wayland neglect), nothing modified, and the report matches the known live state (Metis U4: expect ~45 `!` conflicts, NOT an empty report).
- [x] F4. Scope fidelity - `git diff <base>..HEAD --stat`: exactly `link-files.bash`, `link-context.txt` (new), `README.md`; nothing under `common/`, `linux/`, `macos/`, `setup/`, `setup-os`; no stray files; `.gitignore` NOT in the diff (its working-tree edit stays uncommitted); `.codegraph/`/`.claude/` not tracked. Compare against this plan's Must-NOT-have list.

## Commit strategy
One commit per todo, in todo order, on top of the current HEAD (92f956c). Repo style ("Area: description" per `git log --oneline`):
1. `link-files: add --refresh to capture new files in linked dirs`
2. `link-files: add --audit link-drift report with context neglect` (includes new `link-context.txt`)
3. `link-files: add --no-backup to skip .bak under --force`
4. `README: document --refresh, --audit and --no-backup`
Never amend a commit a later todo depends on. Each commit leaves the repo functional: `bash -n link-files.bash` + a fixture `--refresh --dry-run`/`--audit` pass at every boundary.
Git hygiene (pinned, Metis C2/C3): the working tree has a deliberate split `.gitignore` state (`MM .gitignore`: staged adds `.omo/`/`.codegraph/`/`.claude/` ignores, unstaged removes them) and untracked `?? .omo/`. Workers MUST `git add` only their own files (script + data + README) and the specific evidence file via `git add -f .omo/evidence/task-<N>-link-refresh-audit.txt` (force-add, since the staged ignore list covers `.omo/`); MUST NOT `git add .gitignore`, `.codegraph/`, `.claude/`, or `.omo/notepads` state files. Evidence append-only via `cat >>`.

## Success criteria
1. `./link-files.bash --refresh` (in a fixture or on the real machine) moves newly-appeared files inside linked dirs into the repo and symlinks them back, never touching existing repo content, with working `--dry-run`/`--yes`/pattern/confirm and rollback on failure.
2. `./link-files.bash --audit` reports both drift directions read-only, neglects `x11` files under a wayland session (and vice versa), returns 0/1 per the contract, and never modifies anything.
3. `./link-files.bash --force --no-backup` replaces conflicting real files without `.bak` files, errors without `--force`, and refuses directory conflicts.
4. `link-context.txt` + README document the mechanism so the user can extend neglect to "similar scenarios" (new contexts, new relpaths) without touching the script logic.
5. Repo stays bash 3.2 compatible, `set -e`-safe, one commit per todo, evidence ledger complete, real `$HOME` untouched except the read-only audit smoke.
