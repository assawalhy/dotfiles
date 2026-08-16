# Task 14 Evidence — nvim-config-cleanup-and-java

**Task:** Link new files into ~/.config/nvim
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (2/2 criteria)

## Acceptance criteria

### 1. `./link-files.bash --audit '.*nvim.*'` exits 0

```
$ ./link-files.bash --audit '.*nvim.*'
audit context: wayland (neglecting: x11: .Xmodmap, x11: .xinitrc)
Audit clean (58 links correct).
$ echo $?
0
```

Exit 0 — all 58 nvim links are correct (per-file symlinks into the repo).
The audit header shows the wayland session context neglecting the x11-only
files (`.Xmodmap`, `.xinitrc`) — expected on wayland, not nvim drift. The
full unfiltered audit reports the same: the only non-nvim finding is the
x11-neglected `.xinitrc`, which is session-context, not link drift.

### 2. `readlink ~/.config/nvim/lua/config/options.lua` contains 'dotfiles/common/.config/nvim'

```
$ readlink ~/.config/nvim/lua/config/options.lua
/home/ms/myp/dotfiles/common/.config/nvim/lua/config/options.lua
```

The live `~/.config/nvim/lua/config/options.lua` is a symlink into
`dotfiles/common/.config/nvim` — the new `lua/config/` tree is live.

## Summary

All 2 acceptance criteria PASS. `link-files.bash` linked the new files
(`lua/config/*`, `lua/plugins/{ui,editor,git,blink,jdtls,conform,trouble}.lua`,
`after/plugin/lsp.lua`, `after/ftplugin/java.lua`) as per-file symlinks into
`~/.config/nvim`; the audit is clean (58 links correct, exit 0). No `--force`
was needed (no conflicts — new paths only). The x11-neglected `.xinitrc`
finding on the full audit is expected on wayland and unrelated to nvim.