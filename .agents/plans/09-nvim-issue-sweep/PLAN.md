# PLAN — nvim issue sweep (#2, #12, #6, #5, #8)

## Goal
Resolve the nvim-focused open issues, one branch + PR per issue, plans and
decisions commented on each issue, nothing pushed to `main`.

## Isolation
- Base: `origin/master` @ `f81e01e`.
- One git worktree per issue branch under `/tmp/opencode/`; the main tree and
  the concurrent session stay untouched.
- Plan text is also posted as issue comments (per the request).

## Outcome
| Issue | Result |
|---|---|
| #2 Lspsaga | Already fixed; evidence comment + closed. No PR. |
| #12 large files | 1 MiB guard; treesitter/LSP/folds/diagnostics/swap/undo opt-out. PR #14. |
| #6 git gutter | gitsigns `numhl = true` (VSCode line-number color). PR #15. |
| #5 finder/explorer | Already satisfied since `c83e8d6`; closed, no change. |
| #8 agents configs | Implemented by epic 03; commented + closed. |

## Decisions
- #12 detected by byte size (`fs_stat` at `BufReadPre`); line count would need a
  read first. Rejected parser/token heuristics (circular).
- #6 `numhl`, not `linehl`: colors the number column as requested; `linehl`
  tints the whole line and is not what VSCode does.
- #5 no change: the requested behaviour already exists; flipping
  `hide_gitignored` would hide entries VSCode keeps visible.
- #2/#8 close-only, no code.

## Verification
- `nvim --headless --clean` load of the changed Lua files; 2 MB file gets
  `large_file=true`, small file stays `nil`.
- `vim.lsp.enable(fn)` accepted on nvim 0.12.4.
- `bats tests/link-files.bats` 99 ok / 0 fail; `tests/select.bats` 5 ok.
