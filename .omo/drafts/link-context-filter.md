# Draft: link-context-filter

status: plan-written (awaiting delivery decision)
pending action: user chooses start-work now vs high-accuracy Momus dual review first
plan: `.omo/plans/link-context-filter.md` (written 2026-08-15, post-approval, Metis findings folded in)
dirty_worktree note: `ctx2.txt` (untracked) is USER scratch — do not touch, do not commit, out of scope. Pre-existing uncommitted README.md/link-files.bash hunks from earlier --diff/--no-backup work — stage per-commit with `git add -p`.

## Request (user, verbatim intent)

> .Xmodmap appears in the link list despite being in wayland, let's use the
> link-context to tag specific files for specific environments and use this an
> initial filter for all the operations that audit,link,diff,list the files

## Routing

- Intent: **CLEAR** (outcome known; only preference forks open).
- Classify: **Standard** (1 main file + 2 doc files + 1 data file).

## Exploration findings (evidence)

- `link-context.txt` exists (repo root), format `<context>: <relpath>`,
  contexts wayland/x11/headless. Currently: `x11: .Xmodmap`, `x11: .xinitrc`.
  Header comment says "Context-neglect list for --audit".
- `link-files.bash` (834 lines, bash 3.2 compatible — no assoc arrays,
  no readarray):
  - `session_context()` :537-545 — WAYLAND_DISPLAY → wayland, elif DISPLAY →
    x11, else headless. Live machine: `WAYLAND_DISPLAY=wayland-0` → wayland.
  - `read_contexts()` :550-555 — reads CTX_FILE into `$CTX_TMP` (mktemp),
    strips comments/blank/malformed lines. Currently called ONLY in the
    `--audit` path (:828).
  - `neglected()` :560-572 — rel neglected iff listed in CTX_TMP AND not for
    current session context. Currently called ONLY inside audit().
  - `collect()` :169-204 — builds `$merged` (full rel list, overlay-wins,
    pattern-filtered), `$desired` (`$HOME/$rel` for every merged rel),
    `$mdirs` (stale-scan dirs from ALL roots). Trap :174 cleans temps.
  - Picker reads `$merged` (:318) → neglected files DO appear in the link
    list today (user's complaint). classify/preview/confirm/apply/diff all
    operate on classify's arrays built from `$merged`.
  - `find_stale()` :407-422 — skips symlinks whose abs path is in `$desired`
    (:415). So a full `$desired` is what protects correctly-linked neglected
    files from being removed as stale.
  - `refresh_scan()` :432-482 — dir list from `$merged` (:477-481); in-repo
    exclusion via `grep -Fxq "$f" "$desired"` (:449). F2=yes ⇒ candidates
    must additionally skip neglected rels.
  - `audit()` :574-637 — per-line `neglected()` checks on all four repo-side
    loops (:596/603/610/617) + rfr loop (:626); `suppressed` counter;
    header "audit context: %s (neglecting: %s)" (:588). With the early
    filter, repo-side checks become dead; rfr candidates are filtered by
    refresh_scan (F2=yes) → all per-line checks removable.
  - `preview()`/`confirm()`/`apply()` operate on classify arrays → inherit
    the early filter with zero changes.
- README.md: "What gets linked" (:104-107) and "--audit" section (:148-153)
  both describe link-context.txt as audit-only → must be updated.
- Prior plan `.omo/plans/link-refresh-audit.md` T2 pinned the neglect
  predicate semantics (Metis M7): listed AND not-current → neglected;
  multi-context listed → never neglected; missing file → empty neglect.

## Decisions (user-confirmed)

- **D1 (F1): filter is absolute** — no pattern override. `link-files.bash
  '.*Xmodmap'` on wayland matches nothing. Escape hatch = edit
  link-context.txt.
- **D2 (F2): --refresh also respects the filter** — refresh_scan skips
  candidates whose rel is neglected for the current session.
- **D3 (test strategy): fixture-based agent QA** — fake repo + fake $HOME in
  /tmp/opencode, wayland/x11/headless env-var matrix, evidence files under
  .omo/evidence/. No formal test suite committed.

## Design (approach to plan)

1. Move `read_contexts()` call into main flow before `collect()` (remove the
   audit-path call :828). CTX_TMP already in the collect trap.
2. In `collect()`: after building `$merged` (full) and `$desired` (full),
   compute the neglected rel set from CTX_TMP into `$NEG_RELS` (awk: rel is
   neglected iff listed AND not for session_context) and filter `$merged` in
   place (`awk 'NR==FNR{neg[$0]=1;next} !($2 in neg)' NEG_RELS merged`).
   Add `$NEG_RELS` to the trap.
   - `$desired` stays FULL (built pre-filter) → find_stale protection +
     refresh in-repo exclusion intact.
   - Picker/classify/preview/confirm/apply/diff read the filtered merged →
     neglected files invisible in link/list/diff. D1 satisfied with no
     pattern interplay.
3. `refresh_scan()`: add per-candidate `neglected "$rel"` skip (D2). Dir list
   stays from (now filtered) merged → dirs with only neglected files are not
   scanned (consistent with D2).
4. `audit()`: remove all per-line `neglected()` calls and the `suppressed`
   counter/summary suffix; KEEP the "audit context: ... (neglecting: ...)"
   header. Keep `neglected()` function (used by refresh_scan).
5. Docs: link-context.txt header comment; README "What gets linked" +
   "--audit" + "--refresh" sections + usage/help wording; print_help()
   `--refresh`/`--audit` lines.
6. QA fixtures + evidence (fixture recipe from link-refresh-audit plan:
   /tmp/opencode/fx-repo + fx-home, env matrix rows wayland/x11/headless +
   correct-symlink case + multi-context case + neglected-not-in-repo case).

## Scope

IN: link-files.bash (early filter, refresh_scan neglect, audit cleanup),
link-context.txt header, README.md, help text.
OUT: no new flags, no new context values, no session detection changes, no
setup-os changes, no committed test suite, no picker group changes.

## Approval gate

- [ ] status: awaiting-approval (this draft)
- [ ] pending action: write `.omo/plans/link-context-filter.md`
- [ ] on approval: scaffold-plan.mjs → Metis gap analysis → append todos →
      fill TL;DR last → deliver (CLEAR: ask start-vs-Momus).
