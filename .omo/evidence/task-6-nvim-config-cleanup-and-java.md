# Task 6 Evidence — nvim-config-cleanup-and-java

**Task:** Migrate completion to blink.cmp
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (3/3 criteria)

## Acceptance criteria

### 1. `test ! -f common/.config/nvim/lua/plugins/cmp.lua`

```
$ test ! -f common/.config/nvim/lua/plugins/cmp.lua
$ echo $?
0
```

Exit 0 — the 96-line nvim-cmp plugin file is deleted.

### 2. `grep -rn 'nvim-cmp\|LuaSnip\|lspkind\|cmp_luasnip\|cmp-nvim-lsp' common/.config/nvim/lua/plugins/` exits 1

```
$ grep -rn 'nvim-cmp\|LuaSnip\|lspkind\|cmp_luasnip\|cmp-nvim-lsp' common/.config/nvim/lua/plugins/
$ echo $?
1
```

No output, exit 1 — zero remnants of the 7-plugin cmp stack anywhere in
`lua/plugins/`. `friendly-snippets` is kept (blink's snippets provider
auto-loads it).

### 3. blink.cmp loads headless

```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless \
    --cmd 'let g:codeium_enabled = v:false' \
    -c 'lua assert(require("blink.cmp"))' -c 'qa'
$ echo $?
0
```

Exit 0 — `blink.cmp` (version `1.*`) loads cleanly at boot.

## Summary

All 3 acceptance criteria PASS. `lua/plugins/blink.lua` replaces the deleted
`cmp.lua`; the nvim-cmp/LuaSnip/lspkind/cmp_luasnip/cmp-nvim-lsp stack has
zero references in `lua/plugins/`. blink.cmp boots headless with the repo
config (`XDG_CONFIG_HOME` pre-link) and codeium disabled. Keymap preset is
blink's `default` (C-n/C-p select, C-b/C-f scroll docs, C-Space complete, CR
accept, Tab/S-Tab snippet jump) — matches the user's cmp muscle memory, no
binding overrides. T13's lockfile refresh (blink.cmp in, nvim-cmp out) is
verified in task-13 evidence.