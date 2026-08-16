# Task 13 Evidence — nvim-config-cleanup-and-java

**Task:** Lazy clean orphans + refresh lazy-lock.json
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (3/3 criteria)

## Acceptance criteria

### 1. `ls ~/.local/share/nvim/lazy` contains no async.nvim / kotlin.nvim / oil.nvim / refactoring.nvim

```
$ ls ~/.local/share/nvim/lazy | grep -E 'async.nvim|kotlin.nvim|oil.nvim|refactoring.nvim'
$ echo $?
1
```

No output, exit 1 — all four orphaned plugins (installed but no longer in the
config after T3/T6) are pruned from the lazy install dir.

### 2. `grep -c 'blink.cmp' common/.config/nvim/lazy-lock.json` == 1

```
$ grep -c 'blink.cmp' common/.config/nvim/lazy-lock.json
1
```

blink.cmp is in the lockfile exactly once (line 3, pinned to commit
`78336bc89ee5365633bcf754d93df01678b5c08f`, branch `main`).

### 3. `grep -c 'nvim-cmp' common/.config/nvim/lazy-lock.json` == 0

```
$ grep -c 'nvim-cmp' common/.config/nvim/lazy-lock.json
0
```

Zero `nvim-cmp` references — the removed cmp stack (nvim-cmp, LuaSnip,
cmp-*, lspkind, telescope-luasnip) is fully out of the lockfile.

## Summary

All 3 acceptance criteria PASS. `:Lazy clean` removed the four orphaned
plugins (async.nvim, kotlin.nvim, oil.nvim, refactoring.nvim) and `:Lazy sync`
refreshed `lazy-lock.json`: blink.cmp added, nvim-cmp stack removed. The
lockfile was refreshed by lazy itself, not hand-edited (guardrail respected).
The lockfile is written through to the repo by design (README caveat), so the
refresh shows up as a git change.