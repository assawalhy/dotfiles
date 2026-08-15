# link-context-filter - Work Plan

## TL;DR (For humans)

**What you'll get:** `link-context.txt` becomes a real filter instead of an audit-only footnote: on a Wayland session, x11-only files like `.Xmodmap` and `.xinitrc` disappear from the link list, the picker, `--diff`, `--refresh` and `--audit` — and they come back automatically when you're on an X11 session.

**Why this approach:** The filter is applied once, early, to the master file list — every operation (link, list, diff, audit, refresh) inherits it, so there's no per-feature drift. The one tricky part is what stays *unfiltered*: the "already managed" set keeps the neglected files in it, so files that are already correctly linked are never mistaken for stale and removed, and `--refresh` never tries to re-capture a file that's already in the repo.

**What it will NOT do:** It won't add a flag or let a search pattern override the filter (edit `link-context.txt` to change a file's tags — that's the escape hatch). It won't change how sessions are detected, add new contexts, or touch the installer. It won't delete or modify any of your real files — all verification runs on throwaway copies in `/tmp`.

**Effort:** Short
**Risk:** Medium - this script deletes/backups real files under `--force`, so every test runs against a fake home directory; the destructive paths are only exercised there.

**Decisions to sanity-check:** (1) The filter is absolute — a `<pattern>` cannot resurrect a neglected file. (2) `--refresh` also skips neglected files (new x11-only files are only captured while on an x11 session). (3) Stale links to repo files that were deleted (but still listed in `link-context.txt`) are now reported on every session — they're dangling pointers, so the context no longer hides them. (4) Audit's "neglected" count line is gone; the `audit context: wayland (neglecting: …)` header stays.

Your next move: approve, or run a high-accuracy review first. Full execution detail follows below.

---

> TL;DR (machine): Make link-context.txt the initial session filter: drop neglected rels from $merged in collect() (guarded awk, $desired stays full), skip neglected candidates in --refresh, strip dead neglect checks from --audit (delete neglected()), update link-context.txt/README/help; 5 todos (3 script + docs + full QA sweep), fixture-based QA in /tmp/opencode with git-init'd fake repo + wayland/x11/headless env matrix, 4 commits (dirty_worktree: pre-existing uncommitted README/link-files hunks from earlier --diff work — stage per-commit with git add -p), bash 3.2/POSIX-awk safe, effort Short, risk Medium (destructive-file script: QA only on fixtures).

## Scope
### Must have
- `link-files.bash`: `link-context.txt` becomes the session-context filter applied
  UP FRONT in `collect()` — neglected rels are dropped from `$merged` before the
  picker, classify, preview, confirm, apply and `--diff` ever run (D1: absolute,
  no `<pattern>` override).
- `$desired` stays built from the pattern-filtered but neglect-UNFILTERED
  `$merged` (order unchanged: `$merged` -> `$desired` -> then neglect-filter
  `$merged` in place), so `find_stale` (:415) keeps recognizing correctly-linked
  neglected files as wanted, and `refresh_scan`'s in-repo exclusion (:449) never
  double-captures/overwrites a repo file.
- `--refresh` skips candidates whose rel is in the neglected set (D2):
  per-candidate skip inside `refresh_scan`; scan-dir list keeps coming from the
  now-filtered `$merged` (:477-481) so all-neglected dirs are not scanned.
- `--audit`: remove all per-line `neglected()` checks and the `suppressed`
  counter/summary suffix; keep the `audit context: <sctx> (neglecting: ...)`
  header; stale links to DELETED repo files are now reported on every session
  (accepted decision — they are dangling pointers; matches `apply()`).
- `neglected()` function deleted after its last caller (audit) is removed;
  `read_contexts()` called once in main before `collect()` (audit-path call at
  :828 deleted); `$NEG_RELS` added to the collect trap.
- Docs: `link-context.txt` header (all-operations wording + D1 note),
  README.md ("What gets linked", "--refresh", "--audit" sections AND its own
  OPTIONS block), `print_help()`.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- NO pattern override of the context filter (D1). `link-files.bash '.*Xmodmap'`
  on wayland must match nothing.
- NO new CLI flags, NO new context values beyond wayland/x11/headless, NO
  changes to `session_context()` detection logic, NO `setup-os` changes.
- NO changes to the neglect predicate semantics (listed AND not-current ->
  neglected; multi-context listed -> never neglected; missing
  `link-context.txt` -> empty neglect, not an error).
- NO touching `$desired`/`$mdirs` construction order beyond adding the filter
  step; `$desired` MUST remain neglect-unfiltered.
- NO committed test suite (D3: fixture QA only); NO edits outside
  link-files.bash, link-context.txt, README.md.
- The empty-NEG_RELS case (no neglected files, or missing link-context.txt)
  MUST keep every operation working — the filter is a no-op there, never a
  wipeout (Metis CRITICAL #1: the `NR==FNR` trap).
- bash 3.2 / POSIX-awk compatibility (BSD macOS awk): no assoc arrays, no
  readarray, no `${v,,}`, no globstar, no gawk-only features.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: **tests-after, fixture-based** (D3 — same pattern as the
  link-refresh-audit feature). No committed test suite. Evidence files:
  `.omo/evidence/task-<N>-link-context-filter.txt` per todo.
- Fixture recipe (rebuild per todo as needed — CRITICAL: the fake repo MUST be
  `git init`'d, because `refresh_scan`'s `git -C "$REPO" check-ignore` (:457-461)
  skips ALL candidates when git errors on a non-repo, silently emptying every
  refresh/audit-b row):
  ```sh
  rm -rf /tmp/opencode/fx-repo /tmp/opencode/fx-home
  mkdir -p /tmp/opencode/fx-repo/common /tmp/opencode/fx-repo/linux /tmp/opencode/fx-home
  cp /home/ms/myp/dotfiles/link-files.bash /home/ms/myp/dotfiles/link-ignore.txt \
     /home/ms/myp/dotfiles/.gitignore /tmp/opencode/fx-repo/
  printf 'z=1\n' > /tmp/opencode/fx-repo/common/.zshrc
  printf 'x=1\n' > /tmp/opencode/fx-repo/linux/.Xmodmap
  printf 'i=1\n' > /tmp/opencode/fx-repo/linux/.xinitrc
  printf 'm=1\n' > /tmp/opencode/fx-repo/common/.multi
  mkdir -p /tmp/opencode/fx-repo/common/.config/x11app
  printf 's=1\n' > /tmp/opencode/fx-repo/common/.config/x11app/settings
  mkdir -p /tmp/opencode/fx-repo/common/.config/x11only
  printf 'o=1\n' > /tmp/opencode/fx-repo/common/.config/x11only/conf
  cat > /tmp/opencode/fx-repo/link-context.txt <<'EOF'
  # Context-neglect list. Files tagged for a context other than the current
  # session are excluded from linking, listing, --diff, --audit and --refresh.
  # Each line: <context>: <relpath>
  # Contexts: wayland, x11, headless. A relpath may appear on multiple
  # lines (relevant in several contexts). Comments/blank lines on their own
  # line. No globs. Relpath is relative to common/, linux/ or macos/.
  x11: .Xmodmap
  x11: .xinitrc
  x11: .config/x11app/settings
  x11: .config/x11only/conf
  wayland: .multi
  x11: .multi
  EOF
  git -C /tmp/opencode/fx-repo init -q
  git -C /tmp/opencode/fx-repo add -A && git -C /tmp/opencode/fx-repo commit -qm init
  ```
  Run the fixture's own `link-files.bash` with `HOME=/tmp/opencode/fx-home` and
  the env matrix below. `REPO` resolves from the script's own location, so the
  fixture script must be the one invoked (absolute path
  `/tmp/opencode/fx-repo/link-files.bash`).
- Env matrix (each row = exact env for the invocation):
  - wayland: `WAYLAND_DISPLAY=wayland-0 DISPLAY=`
  - x11:     `WAYLAND_DISPLAY= DISPLAY=:0`
  - headless: `WAYLAND_DISPLAY= DISPLAY=`
- QA rows (assertion per row; each todo references the rows it covers):
  - R1 wayland+missing: fx-home has no .Xmodmap/.xinitrc -> menu/dry-run MUST
    NOT contain them, MUST contain .zshrc; `--audit` exit 1 reports `.zshrc`
    `[missing]` but NOT .Xmodmap/.xinitrc.
  - R2 wayland+correct symlink: `ln -s /tmp/opencode/fx-repo/linux/.Xmodmap
    /tmp/opencode/fx-home/.Xmodmap` -> dry-run silent for it (no `-`/`*`/`!`),
    `--audit` clean for it, find_stale must NOT remove it.
  - R3 wayland+real-file conflict: real fx-home/.Xmodmap -> `--force
    --no-backup --dry-run` shows NO `~ .Xmodmap` line; `--audit` no
    `! [conflict]` for it.
  - R4 x11+missing: `--dry-run` DOES show `+ .Xmodmap`; audit reports
    `+ [missing]` exit 1.
  - R5 headless: behaves like wayland for x11-tagged rels.
  - R6 D1 pattern: wayland `link-files.bash '.*Xmodmap'` -> "Nothing to link"
    (or empty preview), exit 0, nothing created in fx-home.
  - R7 empty-context regression: DELETE fx-repo/link-context.txt -> wayland
    `--dry-run` MUST still list `.zshrc` and `.Xmodmap`; audit reports them;
    nothing broken (proves the `[ -s "$NEG_RELS" ]` guard).
  - R8 stale-deleted: `rm fx-repo/linux/.Xmodmap` (context line stays), keep
    fx-home/.Xmodmap -> repo symlink -> wayland audit reports `- stale link`,
    exit 1; `--dry-run` shows `-` (accepted, context-independent).
  - R9 mixed-dir: dir `.config/x11app` has neglected `settings` + NEW
    `fx-home/.config/x11app/newfile` -> wayland `--refresh --dry-run` and audit
    MUST NOT capture/report newfile; x11 session MUST capture it.
  - R10 all-neglected-dir: `.config/x11only` -> NEW `fx-home/.config/x11only/
    new2` -> wayland refresh/audit invisible; x11 captures it.
  - R11 multi-context: fx-home lacks `.multi` (listed wayland+x11) -> reported
    `+ [missing]` on BOTH wayland and x11 (never neglected).
  - R12 diff: real-file conflict on `.zshrc` (non-neglected) + wayland ->
    `--diff --dry-run` shows the `.zshrc` diff and NOT `.Xmodmap`.
  - R13 audit summary: wayland all-correct -> `Audit clean (N links correct).`
    with NO `, M neglected` suffix.

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.

- **Wave 1 — script (todos 1-3):** sequential — todos 2 and 3 edit the same
  file and depend on todo 1's filter; todo 3 deletes `neglected()` only after
  todo 2 has switched `refresh_scan` to the grep check (todo 2 must NOT delete
  the function; audit still calls it until todo 3).
- **Wave 2 — docs + full QA sweep (todos 4-5):** todo 5 depends on 1-4.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1. Early filter in collect() | — | 2, 3, 4, 5 | — |
| 2. refresh_scan neglect skip | 1 | 3, 4, 5 | — |
| 3. audit() cleanup + delete neglected() | 1, 2 | 4, 5 | — |
| 4. Docs (link-context.txt, README, help) | 1, 2, 3 | 5 | — |
| 5. Full env-matrix QA sweep | 1, 2, 3, 4 | — | — |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->

- [x] 1. `link-files.bash`: apply the session-context filter at collect time
  What to do / Must NOT do:
  - Move the `read_contexts` call: in main() (:810-834), call `read_contexts`
    right after `read_ignores` and BEFORE `collect`; DELETE the audit-path call
    at :828. (Function definitions are hoisted in bash — `read_contexts` at
    :550 is callable from main.)
  - In `collect()` (:169-204), after `$mdirs` is built, add, in this exact
    order:
    ```bash
    NEG_RELS="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
    awk -v sctx="$(session_context)" '
      { ctx = $0; sub(/: .*/, "", ctx)
        rel = $0; sub(/^[^:]*: /, "", rel)
        if (ctx == sctx) cur[rel] = 1
        seen[rel] = 1 }
      END { for (r in seen) if (!(r in cur)) print r }' "$CTX_TMP" > "$NEG_RELS"
    if [ -s "$NEG_RELS" ]; then
      awk -F'\t' 'NR==FNR{neg[$0]=1;next} !($2 in neg)' "$NEG_RELS" "$merged" \
        > "$merged.tmp" && mv "$merged.tmp" "$merged"
    fi
    ```
    - `$NEG_RELS` = rels listed in link-context.txt for a context OTHER than
      the current session (the exact neglect predicate; empty CTX_TMP ->
      empty NEG_RELS).
    - The `[ -s "$NEG_RELS" ]` guard is MANDATORY: the `NR==FNR` idiom with an
      empty first file consumes every merged line and outputs 0 lines (verified
      on gawk + mawk) — without the guard, a machine with no neglected files
      would see an empty link list everywhere (Metis CRITICAL #1).
    - `-F'\t'` is MANDATORY (list_root emits `<root>\t<rel>`; a repo path
      containing whitespace otherwise corrupts `$2`).
    - Do NOT build `$desired` from the filtered merged: `$desired` MUST keep
      the neglect-unfiltered rels (full = neglect-unfiltered; the existing
      pattern filter at :192 applies exactly as today, and `$desired` is built
      after it, as today) — `find_stale` (:415) and `refresh_scan` (:449) rely
      on it to protect neglected-but-linked files and to never double-capture
      a repo file.
    - Add `"$NEG_RELS"` to the collect trap (:174).
    - Do NOT touch `session_context()`, the neglect predicate semantics,
      `$mdirs`, or the pattern filter.
  - Update the collect() comment (:184-186) to mention that the neglect filter
    now runs at collect time on top of the existing pattern filter.
  - Must NOT add any flag, override, or change to `session_context()`.
  Parallelization: Wave 1 | Blocked by: — | Blocks: 2, 3, 4, 5
  References (executor has NO interview context - be exhaustive):
  - `link-files.bash`: collect() :169-204 (trap :174; merged build :190-192;
    desired :194; mdirs :200-203), read_contexts() :550-555, session_context()
    :537-545, audit-path read_contexts call :828, main :810-834, picker narrow
    :343-344 (pattern precedent for the filter awk).
  - `.omo/plans/link-refresh-audit.md` T2: the pinned neglect predicate
    (Metis M7): listed AND not-current -> neglected; multi-context -> never
    neglected; missing link-context.txt -> empty neglect, no error.
  - Metis findings (this plan): #1 empty-NEG_RELS guard, #2 `-F'\t'`,
    #3 exact parser program (single parser; matches bash `${line%%: *}` /
    `${line#*: }` splitting at the FIRST `": "`).
  Acceptance criteria (agent-executable):
  - `bash -n /tmp/opencode/fx-repo/link-files.bash` passes (also run against
    the real repo copy after copying the edited script into the fixture).
  - Fixture R1 wayland+missing: menu/dry-run contain `.zshrc`, NOT
    .Xmodmap/.xinitrc.
  - Fixture R7 empty-context: with link-context.txt deleted, wayland dry-run
    STILL lists `.zshrc` AND `.Xmodmap` (guard works — no wipeout).
  - Fixture R4 x11+missing: `+ .Xmodmap` IS listed.
  - Fixture R2 wayland+correct symlink: `.Xmodmap` silent; `--dry-run` does
    not propose removing it.
  QA scenarios (name the exact tool + invocation):
  - happy: rebuild fixture per the Verification strategy recipe (git init!),
    then `HOME=/tmp/opencode/fx-home WAYLAND_DISPLAY=wayland-0 DISPLAY=
    /tmp/opencode/fx-repo/link-files.bash --dry-run` -> assert .zshrc present,
    .Xmodmap/.xinitrc absent; `... --audit` -> no x11 lines, exit 1 (`.zshrc`
    missing); `HOME=... WAYLAND_DISPLAY= DISPLAY=:0 ... --dry-run` -> `.Xmodmap`
    present.
  - failure: R7 — `rm /tmp/opencode/fx-repo/link-context.txt` then the wayland
    dry-run MUST still list `.zshrc` and `.Xmodmap` and exit 0 (guard); R6 —
    `HOME=... WAYLAND_DISPLAY=wayland-0 DISPLAY= /tmp/opencode/fx-repo/
    link-files.bash '.*Xmodmap'` -> prints "Nothing to link" (or empty output),
    exit 0, `find /tmp/opencode/fx-home -newer /tmp/opencode/fx-home -name
    '.Xmodmap'` proves nothing was created.
  Evidence: `.omo/evidence/task-1-link-context-filter.txt`
  Commit: Y | `link-files: filter the link set by session context at collect time`

- [x] 2. `link-files.bash`: make `--refresh` respect the context filter
  What to do / Must NOT do:
  - In `refresh_scan()` (:432-482), add the skip IMMEDIATELY AFTER
    `rel="${f#$HOME/}"` (:447) and BEFORE the `$desired` check (:449):
    ```bash
    # neglected for this session -> never captured (link-context.txt)
    if grep -Fxq "$rel" "$NEG_RELS"; then continue; fi
    ```
    (`grep` inside an `if` is exempt from `set -e`; identical shape to the
    `$desired` check at :449.)
  - Do NOT delete `neglected()` in this todo — audit() still calls it until
    todo 3. Do NOT call `neglected()` from refresh_scan: the grep against
    `$NEG_RELS` is the single parser (Metis #3, option b).
  - Scan-dir list (:477-481) stays derived from the now-filtered `$merged` —
    this is INTENDED (D2): dirs whose only files are neglected are not scanned
    on this session, so new files inside them are invisible to refresh and
    audit-b on this session, and visible on the owning session (documented
    consequence, Metis #5).
  - Must NOT change the mirror-root rule, the `$desired` in-repo check, or the
    git check-ignore logic (:457-461).
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 3, 4, 5
  References (executor has NO interview context - be exhaustive):
  - `link-files.bash`: refresh_scan() :432-482 (rel at :447, desired check
    :449, git check-ignore :457-461, dir list :477-481).
  - `$NEG_RELS` produced by todo 1 in collect(); trap covers it.
  Acceptance criteria (agent-executable):
  - Fixture R9 mixed-dir: wayland `--refresh --dry-run` must NOT propose
    capturing `fx-home/.config/x11app/newfile`; with `WAYLAND_DISPLAY=
    DISPLAY=:0` it MUST propose it (as `+ ... [refresh] -> common`).
  - Fixture R10 all-neglected-dir: wayland refresh/audit must not mention
    `fx-home/.config/x11only/new2`; x11 session must.
  - `bash -n` passes.
  QA scenarios (name the exact tool + invocation):
  - happy: per recipe, create `newfile` inside `.config/x11app`; wayland:
    `HOME=/tmp/opencode/fx-home WAYLAND_DISPLAY=wayland-0 DISPLAY=
    /tmp/opencode/fx-repo/link-files.bash --refresh --dry-run` -> output has
    NO `newfile`; x11: `WAYLAND_DISPLAY= DISPLAY=:0 ... --refresh --dry-run`
    -> output HAS `newfile`.
  - failure: R10 — `new2` inside `.config/x11only`: wayland dry-run -> no
    mention; x11 dry-run -> mentioned. Also confirm a normal capture still
    works: new `fx-home/.newnormal` -> wayland refresh dry-run lists it.
  Evidence: `.omo/evidence/task-2-link-context-filter.txt`
  Commit: Y | `link-files: skip neglected rels in --refresh`

- [x] 3. `link-files.bash`: clean up `--audit` and delete `neglected()`
  What to do / Must NOT do:
  - In `audit()` (:574-637):
    - DELETE the `neglected "$rel"` + `suppressed` lines in ALL FIVE loops
      (stale :594-600, new :601-607, soft :608-614, hard :615-621, rfr
      :624-629). They are dead: repo-side arrays come from the neglect-filtered
      `$merged` (todo 1); rfr candidates are filtered by refresh_scan (todo 2).
    - DELETE the `suppressed` counter variable, its increments, and the
      `, %d neglected` suffix in the clean summary (:632) — becomes
      `Audit clean (%d links correct).` Keep `Audit findings: %d.` (:635).
    - KEEP the `audit context: <sctx> (neglecting: <lines>)` header (:579-591)
      exactly as-is (informational; computed from raw CTX_TMP lines with
      ctx != sctx; the pre-existing multi-context quirk — e.g. "neglecting:
      x11: .multi" on wayland though .multi is not neglected — is accepted and
      documented).
    - Rewrite the audit() doc comment (:529-533): neglect now happens upstream
      (collect filters the merged set; refresh_scan filters candidates);
      audit itself only reports.
    - Rewrite/remove the `neglected()` function (:557-572) and its doc comment
      — delete it entirely (last callers are gone in this todo).
  - Must NOT change: exit-code contract (0 clean / 1 findings), the header
    output, pattern filtering, or any audit output for non-neglected rels.
  - Stale links to DELETED repo files that are still listed in link-context.txt
    are now reported on every session — ACCEPTED and intended (dangling
    pointers are context-independent; apply() always removed them). No check
    is reintroduced for them.
  Parallelization: Wave 1 | Blocked by: 1, 2 | Blocks: 4, 5
  References (executor has NO interview context - be exhaustive):
  - `link-files.bash`: audit() :574-637, neglected() :557-572, audit doc
    comment :529-533, refresh_scan skip (todo 2).
  Acceptance criteria (agent-executable):
  - `grep -n 'neglected' /home/ms/myp/dotfiles/link-files.bash` -> no matches
    (function deleted; no callers remain).
  - Fixture R13 wayland all-correct: audit prints `Audit clean (N links
    correct).` with no `, M neglected` suffix, exit 0.
  - Fixture R1 wayland+missing: audit still reports `.zshrc [missing]` and
    NOT .Xmodmap/.xinitrc, exit 1.
  - Fixture R8 stale-deleted: wayland audit reports `- stale link` for the
    deleted .Xmodmap, exit 1 (accepted behavior).
  - Fixture R11 multi-context: `.multi` reported `+ [missing]` on both wayland
    and x11.
  - `bash -n` passes.
  QA scenarios (name the exact tool + invocation):
  - happy: R1/R13/R11 rows via `HOME=/tmp/opencode/fx-home WAYLAND_DISPLAY=
    wayland-0 DISPLAY= /tmp/opencode/fx-repo/link-files.bash --audit; echo $?`.
  - failure: R8 — `rm /tmp/opencode/fx-repo/linux/.Xmodmap` + fx-home symlink
    kept: wayland audit exit 1 with the stale line; x11 audit ALSO reports it
    (context-independent). Also verify the audit header still prints
    `audit context: wayland (neglecting: x11: .Xmodmap, ...)`.
  Evidence: `.omo/evidence/task-3-link-context-filter.txt`
  Commit: Y | `link-files: drop redundant neglect checks from --audit`

- [x] 4. Docs: `link-context.txt`, README.md, `print_help()`
  What to do / Must NOT do:
  - `link-context.txt` (repo root): replace the header comment block (:1-4)
    with all-operations wording, e.g.:
    ```
    # Context-neglect list. Files tagged for a context other than the current
    # session are excluded from linking, listing, --diff, --audit and --refresh.
    # Each line: <context>: <relpath>
    # Contexts: wayland, x11, headless. A relpath may appear on multiple
    # lines (relevant in several contexts). Comments/blank lines on their own
    # line. No globs. Relpath is relative to common/, linux/ or macos/.
    # This filter cannot be overridden by a filtering pattern; edit this file
    # to change it.
    ```
  - `print_help()` in link-files.bash (:48-95): update the `--refresh` line
    (:70-72) and `--audit` line (:73-78) to state the context filter applies
    to ALL operations (refresh: "...; skips files neglected for the current
    session context (wayland/x11/headless)"; audit: "...; excludes files
    neglected for the current session context, same as linking").
  - README.md — update BOTH its own OPTIONS block (:54-79; same wording
    changes as print_help) AND the prose sections:
    - "What gets linked" (:100-117): the link-context.txt sentence (:104-107)
      becomes: the session-context filter for ALL link operations — a relpath
      tagged for another context (like `x11: .Xmodmap` under wayland) is
      excluded from linking, listing, --diff, --refresh and the audit report.
    - "--refresh" section (:119-138): add one sentence — new files whose
      relpath is neglected for the current session are skipped.
    - "--audit" section (:140-153): rewrite the link-context.txt paragraph
      (:148-153) to say the filter is applied up front for every operation,
      that `--audit` shows `audit context: <ctx> (neglecting: ...)` in its
      header, and that stale links to deleted repo files are reported on any
      session.
  - Do NOT touch setup/ docs, LICENSE, or any other file. Keep the doc
    wording consistent between README and print_help.
  Parallelization: Wave 2 | Blocked by: 1, 2, 3 | Blocks: 5
  References (executor has NO interview context - be exhaustive):
  - README.md: OPTIONS block :54-79, "What gets linked" :100-117,
    "--refresh" :119-138, "--audit" :140-153.
  - link-files.bash: print_help() :48-95.
  - link-context.txt: :1-4.
  - The .omo/drafts/link-context-filter.md decisions D1/D2 for exact wording.
  Acceptance criteria (agent-executable):
  - `grep -n 'for --audit' /home/ms/myp/dotfiles/link-context.txt` -> no match
    (header no longer audit-only).
  - `grep -n 'neglect' README.md` shows the "What gets linked" + "--refresh" +
    "--audit" sections all describe the all-operations filter.
  - `./link-files.bash --help | grep -A2 -- '--refresh'` mentions the session
    context; same for `--audit`.
  - `bash -n link-files.bash` passes.
  QA scenarios (name the exact tool + invocation):
  - happy: the greps above return the new wording (read the updated sections
    to confirm they match the implemented behavior).
  - failure: run `./link-files.bash --help` on the REAL repo and confirm help
    matches the README wording (no drift between the two copies).
  Evidence: `.omo/evidence/task-4-link-context-filter.txt`
  Commit: Y | `docs: document session-context filtering for all link operations`

- [x] 5. Full env-matrix QA sweep + evidence
  What to do / Must NOT do:
  - Rebuild the fixture fresh per the Verification strategy recipe (git init!).
  - Execute EVERY QA row R1-R13 exactly as specified in "Verification
    strategy", across the three env rows (wayland/x11/headless), using the
    fixture's own script (`/tmp/opencode/fx-repo/link-files.bash`) with
    `HOME=/tmp/opencode/fx-home`. For rows requiring a state change (R2/R3/R8/
    R9/R10), rebuild the affected fx-home/fx-repo state before the run and
    record the setup commands in the evidence.
  - Write the full transcript to `.omo/evidence/task-5-link-context-filter.txt`
    (or one file per row under the same name), including: env vars used, the
    exact invocation, full output, and `echo $?` after each run.
  - Must NOT run any invocation that writes to the REAL $HOME or real repo;
    every run goes through HOME=/tmp/opencode/fx-home. The real-repo runs in
    todo 4 (--help) are the only exception.
  - Must NOT mark any row pass on partial output: assert the exact absence
    and presence of lines per row, and the exit code.
  Parallelization: Wave 2 | Blocked by: 1, 2, 3, 4 | Blocks: —
  References (executor has NO interview context - be exhaustive):
  - The "Verification strategy" section of THIS plan (fixture recipe + env
    matrix + QA rows R1-R13).
  - Prior evidence pattern: `.omo/evidence/task-*-link-refresh-audit.txt`.
  Acceptance criteria (agent-executable):
  - All 13 rows pass with the asserted outputs and exit codes; the evidence
    file records every row's command + output + exit code.
  - `grep -c '^PASS' .omo/evidence/task-5-link-context-filter.txt` >= 13 (or
    an equivalent explicit PASS line per row).
  QA scenarios (name the exact tool + invocation):
  - happy: the sweep itself (each row's exact invocation as listed).
  - failure: the negative rows — R6 (pattern does not resurrect), R7 (empty
    context file does not wipe the list), R8 (stale reported on both
    sessions), R10 (all-neglected dir invisible on wayland) — each asserted
    by their exact absence/presence in the transcript.
  Evidence: `.omo/evidence/task-5-link-context-filter.txt`
  Commit: N (evidence only)

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit — every todo's acceptance criteria met; evidence files exist at `.omo/evidence/task-{1..5}-link-context-filter.txt`; no Must-NOT-have violated (no pattern override, no flag additions, `$desired` still neglect-unfiltered, no committed test suite).
- [x] F2. Code quality review — `bash -n link-files.bash` clean; the new awk is POSIX (BSD-macOS-safe); no `neglected` references remain; diff confined to collect/refresh_scan/audit/main/picker-message/print_help + the two doc files; behavior for rels NOT in link-context.txt unchanged (spot-check via R7).
- [x] F3. Real manual QA — run the R1/R6/R7/R8 rows against the fixture from a real terminal session (tmux), including an interactive picker run on wayland env showing `.zshrc` but not `.Xmodmap`; plus `--audit` on the real repo is read-only and shows the wayland context header.
- [x] F4. Scope fidelity — `git diff` shows only: link-files.bash, link-context.txt, README.md, .omo/plans/link-context-filter.md, .omo/drafts/link-context-filter.md, .omo/evidence/*. No other files touched; dirty_worktree respected (pre-existing uncommitted README/link-files changes from earlier --diff/--no-backup work are in the same tree — commits must not silently include unrelated hunks).

## Commit strategy
One commit per script/doc todo, in order, on the current branch (master). Do NOT commit evidence files (`.omo/evidence/` is a workspace artifact; verify with `git status` whether `.omo/plans/` and `.omo/drafts/` are tracked — if they are, commit only the plan/draft files, never evidence).
1. Todo 1: `link-files: filter the link set by session context at collect time`
2. Todo 2: `link-files: skip neglected rels in --refresh`
3. Todo 3: `link-files: drop redundant neglect checks from --audit`
4. Todo 4: `docs: document session-context filtering for all link operations`
Todo 5: no commit. Before each commit, `git status` + `git diff`; the working tree has pre-existing uncommitted changes from earlier session work on README.md and link-files.bash (the --diff/--no-backup feature) in the SAME files — stage hunks deliberately (`git add -p`) so each commit contains only its own hunks.

## Success criteria
- On a wayland session, x11-tagged files (`.Xmodmap`, `.xinitrc`) never appear in the link list, the picker, `--diff` output, `--refresh` candidates, or the `--audit` report — even when explicitly named by a `<pattern>` argument (D1).
- On an x11 session they behave exactly as before (listed/linked/reported).
- Correctly-linked neglected files are left untouched (never stale-removed); repo files are never double-captured by `--refresh`.
- A machine with no `link-context.txt` or an empty neglect list behaves identically to today (no wipeout regression).
- `--audit` still prints its context header and exit-code contract; stale links to deleted repo files are reported on any session (documented).
- README, `--help`, and the link-context.txt header all describe the filter as applying to link/list/diff/refresh/audit.
