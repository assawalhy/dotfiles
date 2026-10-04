# TODO — link-files general fix (issue #25)

- [x] Epic files created (this dir)
- [x] `refresh_scan`: exclusion checks all overlay roots; other-overlay hits
      reported (`?`) + counted, never captured
- [x] `refresh_scan`: batch the candidate filters (one awk + one
      `git check-ignore --stdin`); same skip rules, same output
      — refresh scan 8.582s → 0.42s on this machine (1243 candidates)
- [x] `--fix`: `refresh_scan` before `confirm`, `refresh_apply` after `apply`
- [x] `confirm`/`preview`: capture candidates are actionable; summary says how
      many files move into the repo
- [x] `--no-capture`: link-only `--fix`; wired into help + header comment
- [x] `refresh_apply`: `in_repo_guard` before the capture link
- [x] known issue 1: `--audit --refresh` never writes
- [x] known issue 2: leading whitespace in `link-context.txt` is parsed
- [x] known issue 3: `i [ignored]` wins over `x [neglected]` (report once)
- [x] tests: `fix-` capture to common / overlay-first / audit clean after /
      dry-run moves nothing / ignored not captured / gitignored not captured /
      pattern narrows capture / `--no-capture`
- [x] tests: `refresh-` other-overlay candidate is reported, not captured
      (+ the `?`-only batch and the `--audit` finding)
- [x] tests: rename `six-state` -> `six-state link resolution` (+ dry-run marker test)
- [x] docs: `AGENTS.md` suite counts + prefixes; help text
- [x] verify: `bats tests/link-files.bats` 112 ok / 0 not ok,
      `tests/select.bats` 5 ok, `tests/link-known-issues.bats` 3 of 4 green
- [x] verify: real-machine read-only run — no capture candidates on this
      machine (`--audit` clean before the change)
- [x] commit per milestone, push, PR `Closes #25`

## Verification log

- Reproduced the gap first: `--fix --yes` with a new file in a linked dir
  reported `Nothing to do (4 links already correct)` while `--audit` reported
  `+ .config/mpv/extra.conf [unlinked]`.
- Reproduced the overlay duplication the generalization had to fix:
  `macos/.config/maconly/only.conf` + `~/.config/maconly/only.conf` on Linux
  was captured into `linux/.config/maconly/only.conf`.
- Cost measured before/after on this machine: `refresh scan` 8.582s → 0.42s,
  `--audit` total 9.05s → 1.3s (one awk + one batched `git check-ignore --stdin`
  instead of four spawns per candidate).
- `? [other overlay owns this path]` stays an `--audit` finding on purpose: it
  is real drift (a home file the repo does not own on this platform) and
  `--fix` cannot resolve it -- the fix is a human decision about which overlay
  should own the file. So "--fix then --audit is clean" holds for every state
  `--fix` can act on, and the `?` line is the one that needs you.
- Known blind spot, left alone on purpose: a foreign symlink inside a linked
  dir (`~/.config/foo/bar -> /opt/x`) is invisible to both scans -- it is not
  `-type f`, and `find_stale` only looks at links whose target is under `$REPO`.
