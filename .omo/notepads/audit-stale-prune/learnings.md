
## task 1 (2026-08-15) — bats harness + baseline suite (commit 80fdb15)

- 57/57 tests pass against the current committed script; evidence in .omo/evidence/task-1-audit-stale-prune.txt.
- **picker + confirm stdin**: the fallback menu consumes ONE line, the confirmation prompt the NEXT.
  `printf 'a\n'` alone links NOTHING (confirm reads EOF → exit 1). Tests must pipe `a\ny\n` (or `n`, `n\n`, `2-3\ny\n`).
  The menu is rendered to /dev/tty (suppressed under bats), so only effects are assertable.
- **Menu order** (matters for number/range picks): OSDIR rels sorted FIRST (linux: .config/shell/os.sh), then common sorted.
  Overlay-merge keeps list_root's per-root sort; it is NOT a global sort.
- **--force backs up real files only**. A foreign symlink is replaced outright (rm -f + ln -s), never backed up —
  the plan's ".bak with content preserved" for foreign symlinks does NOT match the script; real-file conflicts do get
  .bak.<STAMP> with content preserved (cmp-verified).
- **in_repo_guard HOLE (for later todos)**: the guard only tests the parent dir's last component. When the parent
  doesn't exist through the symlink (e.g. ~/.config -> repo/common/.config and linking .config/shell/os.sh),
  `[ -d ]` is false → guard skipped → `mkdir -p` walks the symlink and `ln -s` writes INTO the repo.
  Verified: picker '1' (os.sh) created a repo-side symlink common/.config/shell/os.sh. A full run removes the dir
  symlink as stale first (guard unreachable); only picker-narrowed runs (mdirs without $HOME) reach the guard.
  The guard test uses picker '2-3' (mpv.conf/init.lua — parents exist through the link → refusing, exit 1).
- **--refresh and audit [unlinked] REQUIRE a git repo in the fixture**: `git check-ignore --no-index` returns 128 in
  a non-repo → candidate silently skipped. All refresh-* tests and audit-unlinked use `fixture_new <name> git`.
- Ignore behavior locked in: entry ADDED with live link → audit `-  .zshrc  stale link` (exit 1); entry REMOVED
  without link → `+  bin/.github  [missing]`; entry removed WITH correct link → silent.
- bats 1.10 runs test bodies with errexit-like behavior: intermediate failing assertions fail the test.
- setup() stubs uname Linux by default (hermetic OS); overlay tests override with stub_uname Darwin.
- Audit header on wayland/headless: "audit context: wayland (neglecting: x11: .Xmodmap, x11: .xinitrc)" — so
  context assertions must match finding LINES, not the bare string ".Xmodmap" (it appears in the header).

## task 2 (2026-08-15) — find_stale -lname scan + three-way classification (commit a80d83b)

- **guard test needed a fixture change**: the new `find -lname "$REPO/*"` scan catches an ABSOLUTE dir symlink
  `~/.config -> <repo>/common/.config` as stale (repo-pointing, not in $desired) and apply removes it BEFORE
  link_one's in_repo_guard can fire — the old picker-narrowed run escaped this via the $mdirs rebuild (now deleted).
  Fixed by switching the guard test's symlink to a RELATIVE target (`../repo/common/.config`): -lname glob-matches
  the literal target string, so relative targets skip the stale scan and the guard stays reachable. Test intent
  (refuse dir symlinks resolving into the repo) preserved; guard still covered.
- **ignore- ADDED test flip**: entry added with live link → audit now exits 0 with NO finding line (link moved to
  `ignored`, which Todo 3 prints as `i`). Asserted `output_not_has_finding .zshrc` + exit 0 + `--yes` run leaves the
  link. Todo 3 flips this to positive `i` + exit 1.
- **ignored+dangling**: `[ ! -e ]` wins over the ignore match — repo file deleted + ignore entry present → still
  `- stale link` (exit 1). Locked by `ignore- ignored but dangling...` test.
- **fully-deleted dir gap closed**: rm -rf common/.config → both ~/.config/mpv/mpv.conf and ~/.config/nvim/init.lua
  reported stale by --audit, removed by --yes, re-audit clean (exit 0). The old $mdirs scan couldn't see them.
- **neglected-but-linked still preserved**: $desired is neglect-UNFILTERED (built before the NEG_RELS filter), so
  ~/.Xmodmap on wayland stays in desired → skipped by find_stale. context- tests unaffected.
- **awk ignore rule reused verbatim** from list_root (`rel == $0 || index(rel, $0 "/") == 1` over $IGN_TMP) — safe
  in an `elif` under `set -e` (conditions are exempt from errexit).
- **stale- foreign/relative tests**: foreign `~/.zshrc -> /etc/passwd` and relative `-> ../repo/common/.zshrc` are
  never `-` listed (assert `!= *"-  .zshrc"*` — note output_has_finding would match the `! [conflict]` line, so the
  negative assertion must target the `-  ` marker specifically).
- **overlay- leftover**: macos .hushlogin on linux → audit `-  .hushlogin  stale link` (exit 1), --yes prunes it.
- **--diff hunks were already committed** (eecaa64) — link-files.bash working tree was clean before this todo, so
  plain `git add <file>` was safe; still staged only the two files. Remaining dirty files (.omo/*, lazy-lock.json,
  lsp.lua) are unrelated and untouched.
- Full suite 64/64 green; filtered `^(stale|ignore-|overlay-)` 18/18; `grep -n mdirs link-files.bash` empty;
  `bash -n` clean on all three files.

## task 3 (2026-08-15) — neglinked detection + audit i/x reports (commit 5dd4102)

- **find_neglinked idiom**: `[ -L ]` then `[ -e ]` (follows the link) then `case "$t" in "$REPO"/*)` — the
  `[ -e ]` check is what keeps dangling neglected links out of the `x` report; find_stale owns them as `-`.
  The "reported once" invariant falls out of $desired being neglect-UNFILTERED + the -e check — no extra
  filtering needed, exactly as the plan predicted.
- **wanted-contexts label**: awk over $CTX_TMP `$2 == r` matches the rel, `sub(/: .*/, "", $0)` strips it
  leaving the ctx, joined with commas. Multi-context order = file order in link-context.txt (verified:
  `x11,headless` when `headless: .Xmodmap` is appended after `x11: .Xmodmap`). bash 3.2 safe (no assoc arrays).
- **audit loops**: `i  %-44s` uses `${ignored[$i]#$HOME/}` (absolute paths in the array, like stale); the
  `x` loop prints the rel directly (neglinked_rel holds rels). Both increment findings → exit 1. No `=~`
  re-check needed: find_stale/find_neglinked already applied the pattern filter.
- **assertion gotchas confirmed**: `output_has_finding`'s `^[+*!~-]` regex does NOT match `i`/`x` lines —
  used direct `[[ "$output" == *"i  .zshrc"* ]]` / `*"x  .Xmodmap"*` instead. The audit header contains
  `neglecting: x11: .Xmodmap, x11: .xinitrc` — bare `.Xmodmap` assertions would false-positive; always
  assert the finding LINE (`x  .Xmodmap` — the double space after the marker never appears in the header).
- **x11-session clean check needs .xinitrc linked too**: after wayland --yes + manual .Xmodmap link, an
  x11 audit would report `.xinitrc` as `+ [missing]` (it was neglected on wayland) — the "not neglected on
  x11" test runs `run_link_sess x11 --yes` first so the audit is genuinely clean (exit 0).
- **dangling-neglected count assertion**: `grep -cE '^[-x]  \.Xmodmap( |$)'` = exactly 1 — the header's
  `x11: .Xmodmap` doesn't match (line-anchored, double-space marker).
- **real file at neglected path**: invisible to everything — not a symlink (find_stale's -lname scan and
  find_neglinked's `[ -L ]` skip it), not in $merged (neglect filter) so classify never sees it, and
  refresh_scan only scans inside linked dirs ($HOME root is never scanned). Audit clean, exit 0.
- **ignore- REMOVED-with-correct-link**: link bin/.github manually after the ignore entry is dropped →
  in $desired → find_stale skips it → audit clean (exit 0). Both ignore directions now locked.
- Full suite 72/72 green (64 baseline + 8 new: 2 audit-, 5 context-, 1 ignore-); filtered
  `^(audit-|context-|ignore-)` 30/30. Evidence in .omo/evidence/task-3-audit-stale-prune.txt.
- Parallel session committed its own nvim work (4b3a4ec) mid-todo; my commit 5dd4102 staged ONLY
  link-files.bash + tests/link-files.bats (git show --stat verified).

## task 4 (2026-08-15) — --fix mode + prune loops + fix- tests (commit 3de6385)

- **apply() prune loops MUST be guarded by `if [ -n "$is_fix" ]`** — the plan's literal
  wording ("add the loops after the stale loop") would break two committed T3 invariants:
  a normal `--yes` run must PRESERVE ignored links (`ignore- entry ADDED...` asserts the
  link survives) and neglinked links (`context- neglected-but-linked file is preserved`).
  apply() is shared by --fix and normal runs, and find_stale/find_neglinked populate the
  arrays in main for both. Only --fix un-links ignored/neglinked (plan TL;DR + Must-NOT-have).
  The stale loop stays unconditional (pre-existing T2 behavior).
- **Six-state fixture construction gotchas**: (1) create the drift states AFTER the initial
  clean `run_link --yes` — a wrong-source link or real-file conflict placed before it gets
  resolved/skipped by that run; (2) `printf > ~/.config/mpv/mpv.conf` while it is a symlink
  writes THROUGH the link into the repo file — `rm -f` the link first; (3) `mkhome_link`
  uses plain `ln -s` which fails if the dst exists — `rm -f` first for overwrite states;
  (4) "missing" state = add a NEW repo file (`.newfile`) rather than unlinking an existing
  one — keeps the other states independent.
- **`diff -rq` fails (status 2) on dangling symlinks** — it stats the missing target.
  The dry-run no-change assertion needs `diff -rq --no-dereference` (GNU diffutils ≥3.3;
  fine on Ubuntu 24.04). The T3 audit read-only test never hit this because its fixture
  has no dangling links.
- **confirm() under --fix**: `--fix` sets is_force during parsing, so the "re-run with
  --force" branch never fires; added an explicit `is_fix` branch printing
  `N conflict(s) will be resolved (backed up)` + `N ignored link(s) will be removed` +
  `N session-neglected link(s) will be removed`. actionable counts ignored+neglinked.
- **STAGING HAZARD (near-miss)**: the parallel session's `.omo/*` files were ALREADY
  STAGED in the index before this todo (visible as `A `/`M ` in `git status --short`).
  My first `git commit` swept all 9 files in (f737dcb). Fixed with
  `git reset --soft HEAD~1` (index returns byte-identical to pre-commit) then
  `git commit <paths>...` — pathspec-limited commit leaves the parallel session's staged
  files staged and untouched. Final commit 3de6385 = ONLY link-files.bash + tests/link-files.bats.
  Lesson: check `git status --short` for pre-staged entries BEFORE committing; use
  `git commit <paths>` when the index contains foreign staged work.
- Full suite 80/80 green (72 + 8 new fix-); filtered `^fix-` 8/8. Evidence in
  .omo/evidence/task-4-audit-stale-prune.txt. `--help` shows --fix + i/x legend;
  `--fix --audit` / `--fix --refresh` exit 1 with the exclusivity error.

## task 5 (2026-08-15) — docs (README + config headers) — COMPLETED by orchestrator
- Two subagent attempts backed out over the shared-index hazard (fear that `git commit`
  would sweep the parallel session's staged files). The safe method is a PATHSPEC-LIMITED
  partial commit: `git commit -m "..." -- <paths>` commits ONLY the named paths and leaves
  other staged entries staged. Verified: commit c5fc735 contains exactly README.md +
  link-context.txt + link-ignore.txt; parallel session's staged files untouched.
- README: USAGE + OPTIONS + markers table gained `--fix` and `i`/`x` rows; new
  "Completing the link state (--fix)" section. Acceptance greps: --fix x9, i [ignored] x1,
  x [neglected] x1; stale "future --fix" language removed from link-context.txt.
- link-context.txt header: documents `x [neglected]` reported by --audit, removed by --fix.
- link-ignore.txt header: documents `i [ignored]` (entry added while still linked).
- Full suite 80/80 green after header changes (fixtures copy the real config files).
