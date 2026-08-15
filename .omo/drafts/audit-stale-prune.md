---
slug: audit-stale-prune
status: plan-written (awaiting delivery decision)
intent: clear
pending-action: user chooses start-work now vs high-accuracy Momus dual review first
plan: `.omo/plans/audit-stale-prune.md` (written 2026-08-15, user approved approach + added bats testing; perf of -lname scan verified empirically: 2.0s / 47 candidates on this 60GB home vs 18.8s naive readlink loop)
approach: new --fix mode (deletes stale+dangling+env-mismatch+ignored-but-linked links, completes linking, implies --force) + audit becomes savvy (reports dangling links incl. fully-deleted dirs, `i [ignored]`, `x [neglected]`) via single-pass find -lname scan replacing $mdirs loop + neglinked/ignored classification; testing = committed bats-core suite (tests/link-files.bats + helpers.bash, fixture homes, uname stub, env matrix, no --diff assertions), 5 todos / 5 commits, fixture-only destructive QA.
---

# Draft: audit-stale-prune

## Components (topology ledger)
| id | outcome | status | evidence path |
|---|---|---|---|
| C0 bats test suite | committed tests/link-files.bats + tests/helpers.bash (bats-core 1.10.0 via apt; plain assertions; fixture repos + fake homes; uname stub; env matrix; baseline edge-case coverage of EXISTING behavior: link/classify/overlay/context/ignore/refresh/audit/picker/cli/guard) | active | .omo/evidence/task-1-audit-stale-prune.txt |
| C1 find_stale scan fix | stale detection covers fully-deleted dirs ($HOME-wide `find -lname` scan, only $REPO-targeting links) + three-way classification: dangling → stale, ignore-matched → ignored, other-overlay → stale | active | .omo/evidence/task-2-audit-stale-prune.txt |
| C2 env-mismatch detection | neglinked array: linked + neglected-for-session + target exists, under $REPO | active | .omo/evidence/task-3-audit-stale-prune.txt |
| C3 --fix mode | new flag: deletes stale+ignored+neglinked, links missing, relinks, resolves conflicts (implies --force); prompt/dry-run/pattern; error if combined with --audit/--refresh | active | .omo/evidence/task-4-audit-stale-prune.txt |
| C4 --audit savvy | read-only; new `x [neglected]` and `i [ignored]` reports; stale now includes fully-deleted dirs; exit 0/1 unchanged | active | .omo/evidence/task-3-audit-stale-prune.txt |
| C5 docs | --help, README (options, audit section, conflicts table, new --fix section, link-ignore both-directions note, Testing section), link-context.txt + link-ignore.txt header comments | active | .omo/evidence/task-5-audit-stale-prune.txt |

## Open assumptions (announced defaults)
| assumption | adopted default | rationale | reversible? |
|---|---|---|---|
| Full-home stale scan scope | find_stale scans `find "$HOME" -type l` (target under $REPO, not in $desired) instead of the $mdirs maxdepth-1 loop; stale removal is no longer scoped by the picker | only way to see fully-deleted dirs; safety invariant (REPO-target only) unchanged; dangling links are always garbage | yes (behavior) |
| Manual repo-pointing links | any symlink in $HOME pointing into $REPO outside the managed set is drift → stale | "repo is the source of truth" philosophy; audit = drift report | yes |
| Dangling vs env-mismatch precedence | dangling (target missing) → stale only; target exists + neglected → neglinked only; no double-report | one file = one finding | yes |
| --fix marker | `x` + `[neglected]` (avoids collision with preview `~` = force-resolved) | markers are cosmetic | yes |
| --fix + --audit / --refresh | parse_args errors on the combination | avoids ambiguous precedence | yes |
| QA approach | fixture-based: fake repo + fake $HOME in /tmp/opencode, wayland/x11/headless env matrix (WAYLAND_DISPLAY/DISPLAY), bash -n | script deletes/backs up files; never touch real $HOME (matches prior plan's pattern) | n/a |
| --diff hunks | pre-existing uncommitted --diff work in link-files.bash/README.md stays uncommitted; new commits stage only their own hunks (git add -p); ctx2.txt untouched | dirty worktree convention from prior plan | n/a |

## Findings (cited - path:lines)
- `find_stale()` scans only `$mdirs` (parent dirs of CURRENT repo files, collect() :204-207) with `find "$d" -maxdepth 1 -type l` (:427-442). Fully-deleted dirs never enter `$mdirs` → their dangling links are invisible to normal runs AND `--audit` (audit calls the same classify/find_stale :827-832).
- `$desired` is neglect-unfiltered (collect() :198, comment :211-212) so neglected-but-linked files are deliberately treated as "wanted" → never stale. Prior plan `link-context-filter` (commits e61e3bb→eadf053) removed audit's neglect checks (5572084) — env-mismatch reporting is genuinely new.
- `$NEG_RELS` (collect() :213-223) already holds rels neglected for the current session; `$CTX_TMP` (read_contexts() :573-578) holds all `<context>: <rel>` lines — both available in audit and fix paths.
- `link-context.txt` currently: `x11: .Xmodmap`, `x11: .xinitrc` (live machine is wayland, WAYLAND_DISPLAY=wayland-0).
- `apply()` (:786-807) already removes stale (`rm -f`) and, under `is_force`, backs up conflicts; `--no-backup` validation requires is_force at parse time (:127-130) → --fix must set is_force during parse_args.
- Picker flow rebuilds `$mdirs` from picked rels (:366-370) → full-home scan makes stale removal unconditional (accepted, documented).
- Worktree: uncommitted `--diff` hunks in link-files.bash/README.md (pre-existing, from earlier --diff/--no-backup work); ctx2.txt untracked user scratch.
- EMPIRICAL (2026-08-15, /tmp/opencode/ignfix fixture, read-only vs real home): (A) ignore entry ADDED + live home link → `--audit` reports `- stale link` today (works, but MISLEADING — target still exists; motivates distinct `i [ignored]`); (B) ignore entry REMOVED + no home link → `+ [missing]` (already correct); (C) ignore entry REMOVED + correct link → silent. So ignore BOTH directions already function; the plan adds distinct reporting + QA locks.
- EMPIRICAL (2026-08-15): `find "$HOME" -type l -lname "$REPO/*"` = 2.0s / 47 candidates on this 60GB/1.47M-file home; naive per-link readlink loop = 18.8s (rejected).
- EMPIRICAL (2026-08-15): machine is Ubuntu 24.04 (NOT Arch); `bats` NOT installed; `apt-cache policy bats` → candidate 1.10.0-1 → prerequisite `sudo apt install bats` (SUDO_ASKPASS available per system memo: `SUDO_ASKPASS=/usr/bin/ssh-askpass sudo -A apt install bats`).

## Decisions (with rationale)
1. **New `--fix` flag** (user: "wider and future clean up and fixing and complete linking"): one command that makes $HOME exactly match the repo for the current session context — removes stale (incl. fully-deleted dirs), ignored-but-linked, and env-mismatched links, creates missing links, relinks wrong sources, resolves conflicts with backup. Implies `--force` (so `--fix --no-backup` works). Prompt like other modes; `--dry-run` previews; `--yes` skips; `<pattern>` narrows; never opens the picker; never captures (`--refresh` stays the home→repo direction).
2. **Env-mismatch policy** (user: "using --fix as well"): env-mismatched links are deleted by `--fix` (after confirmation), reported read-only by `--audit`.
3. **`--audit` stays strictly read-only** (exit 0/1, never writes) but reports the new categories.
4. **One scan, one rule**: full-home `find -lname` scan replaces the $mdirs loop; classification: target under $REPO ∧ not in $desired ∧ pattern-matched → dangling → stale; target exists ∧ ignore-matched → ignored (NEW); target exists ∧ not ignored → stale (other-overlay). neglinked = rel in $NEG_RELS ∧ $HOME/$rel is a symlink ∧ target exists ∧ target under $REPO ∧ matches pattern. No double-reporting (dangling wins over ignored/neglinked).
5. **bash 3.2 compatible** (no assoc arrays, no readarray, POSIX find/awk) — hard constraint of the script (:10-12).
6. Markers: `-` stale (unchanged), `i` ignored ([ignored] linked but listed in link-ignore.txt), `x` neglinked ([neglected] wanted on: <ctx>), `~` force-resolved conflicts (existing), `+`/`*`/`!` unchanged.
7. **link-ignore.txt awareness** (user: "modifications to link-ignore.txt should affect the audit — added files/dirs and removed ones"): both directions already work mechanically (empirical A/B/C above); the plan adds the distinct `i [ignored]` category so "added an entry" is clearly visible, keeps `+ [missing]` for "removed an entry", and locks both in with tests. Ignore MATCHING semantics (list_root :160-164 rule) are reused verbatim, unchanged.
8. **bats for testing** (user: "use bash bat for testing and cover most of the edge-cases of the complex linking script"): committed bats-core suite at tests/ (repo root — never linked, only common/+overlay are); plain bash assertions (no bats-assert dependency — keep the suite dependency-free); fixture repos + fake homes per test under $BATS_TEST_TMPDIR (hermetic; destructive paths never touch real $HOME); `uname` stub via exported bash function for macOS overlay tests; WAYLAND_DISPLAY/DISPLAY env matrix; git-init'd fixtures for refresh tests; NO assertions on the uncommitted --diff behavior so the committed suite passes on a clean checkout. Structure: T1 = harness + baseline edge-case suite (existing behavior), T2/T3/T4 = each implementation with its test additions (implementation + test = one todo), T5 = docs. 5 commits (test:, link-files: ×3, docs:).

## Scope IN
- find_stale scan fix + three-way classification (C1); neglinked detection (C2); --fix mode (C3); audit reporting incl. `i [ignored]` and `x [neglected]` (C4); --help/README/link-context.txt/link-ignore.txt docs (C5); fixture QA + evidence for all, incl. link-ignore.txt both-directions scenarios.

## Scope OUT (Must NOT have)
- No changes to `--refresh` capture semantics; --fix never captures home→repo.
- No new contexts in link-context.txt beyond existing wayland/x11/headless; no pattern-override of neglect (prior plan's invariant).
- No changes to link-ignore.txt MATCHING semantics (list_root rule reused verbatim) — only reporting/removal of ignored-but-linked links is new.
- No deletion of real (non-link) files by --fix beyond existing --force backup semantics; no touching symlinks that don't target $REPO.
- No changes to session detection, setup-os, picker, or --diff behavior; ctx2.txt and the pre-existing --diff hunks untouched.
- --fix does NOT resolve `[unlinked]` refresh candidates; those stay --refresh's job.
- No double-reporting: dangling neglected/ignored links are stale only.

## Open questions
None — both owner forks answered by user (--fix mode; env-mismatch handled via --fix).

## Approval gate
status: awaiting-approval
pending action: write .omo/plans/audit-stale-prune.md
approach: see above; on approval, append 5 todos (script: scan fix, neglinked, --fix mode, audit report, docs) + final verification wave, commit strategy (4 commits, git add -p to exclude --diff hunks), then present summary and stop.
