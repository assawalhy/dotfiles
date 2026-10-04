# 19 — link-files: `--fix` = `--audit` clean (issue #25)

## Goal

`--fix` resolves every finding `--audit` reports, so one command reaches the
state the audit defines. Today it acts on 6 of 7 categories; the gap is the
`--refresh` direction (a new real file inside an already-linked dir).

## Approach

- `--fix` pipeline gains `refresh_scan` after `find_neglinked` (so the links it
  creates are not seen as stale in the same run) and `refresh_apply` after
  `apply`. One preview, one prompt, one run.
- Capture candidates join the `--fix` preview as `+ rel [refresh] -> root`;
  the summary states how many files will be **moved into the repo**.
- Capture exclusion asks "does the repo already have this path?" against
  **all** roots (`common/`, active overlay, other overlay), not the
  overlay-resolved `$desired`. An other-overlay hit is reported
  (`? rel [other overlay owns this path]`) and counted as a finding, never
  silently skipped and never captured into a second overlay.
- Batch the per-candidate filter spawns (one `awk` against `link-ignore.txt`,
  one batched `git check-ignore --stdin`, batched membership greps) so the
  scan stops costing ~7 ms per candidate.
- `--no-capture` keeps today's link-only `--fix`.
- Fold in 3 fixable `tests/link-known-issues.bats` entries as separate commits:
  `--audit --refresh` must never write; trim leading whitespace on
  `link-context.txt` lines; `i [ignored]` wins over `x [neglected]`.

## Decisions

| # | Decision | Why | Rejected |
|---|----------|-----|----------|
| D1 | `--fix` covers all 7 audit categories | `--audit` already defines the target state; one name for one job | a new `--all` mode |
| D2 | `refresh_scan` after `find_stale` | a link created by the scan is not in `$desired`, so an earlier scan would delete it as stale | refresh before the stale scan |
| D3 | Exclusion over all overlay roots; other-overlay hits reported | fixes a captured duplicate (`macos/…` file landing in `linux/…`) and makes exclusion independent of the filtering pattern | keep `$desired` (overlay-resolved + pattern-scoped, so incomplete); silent skip (hides drift) |
| D4 | Batch the candidate filters | `--fix` would otherwise cost 8.6 s per run here (1243 candidates x ~7 ms of spawns) | accept the cost on a routine command |
| D5 | `--no-capture` escape hatch | `--fix` now writes into the repo; this is the only way to keep the old behaviour | drop it |
| D6 | `--refresh` stays capture-only; `--fix --refresh` stays an error | `--refresh` is the narrow "adopt only" tool | deprecate/alias `--refresh` |
| D7 | `in_repo_guard` before the capture `ln -s` | reuse of an existing guard now that capture runs from a routine command | leave the exotic path unguarded |

## Milestones

1. `refresh_scan`: overlay-complete exclusion + batched filters.
2. `--fix`: scan before confirm, apply after apply; preview/summary/prompt.
3. `--no-capture` + help/header docs.
4. Known issues #1-#3 (separate commits).
5. Tests: 7 new `fix-`, 1 `refresh-` cross-overlay, `six-state` -> `seven-state`.
6. Full suites + real-machine `--fix --dry-run` / `--audit` smoke test.

## Risks

- `--fix` now moves files into the repo. Mitigated by the preview, the
  confirmation prompt, `--no-capture`, and the already-tested ignore /
  gitignore / `*.bak.*` / `.git/*` / neglect filters. On this machine
  `--audit` is clean, so the capture step is a no-op today.
- D3 changes `--refresh` output for other-overlay candidates (reported instead
  of captured) — covered by a new test.
- Known blind spot (not in scope): a foreign symlink inside a linked dir is
  invisible to both scans (not `-type f`, target not under `$REPO`).
