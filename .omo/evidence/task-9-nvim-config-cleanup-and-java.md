# Task 9 Evidence — nvim-config-cleanup-and-java

**Task:** Add nvim-jdtls plugin and telescope jdt:// URI patch
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (3/3 criteria)

## Acceptance criteria

### 1. `grep -c 'jdt://' common/.config/nvim/lua/plugins/telescope.lua` == 1

```
$ grep -c 'jdt://' common/.config/nvim/lua/plugins/telescope.lua
1
```

The `jdt://` URI monkeypatch is present exactly once (the `is_uri` override
that makes telescope treat `jdt://` URIs as plain filenames).

### 2. `grep -c 'nvim-jdtls' common/.config/nvim/lua/plugins/jdtls.lua` == 1

```
$ grep -c 'nvim-jdtls' common/.config/nvim/lua/plugins/jdtls.lua
1
```

`lua/plugins/jdtls.lua` declares `{ 'mfussenegger/nvim-jdtls', ft = 'java' }`
— lazy-loaded on java filetype only (jdtls is NOT in lspconfig/`vim.lsp.enable`,
guardrail respected).

### 3. Headless jdtls require with a java buffer open

```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless \
    --cmd 'let g:codeium_enabled = v:false' \
    -c 'set noswapfile' \
    -c 'edit /tmp/opencode/java-qa-sample/src/main/java/com/example/Hello.java' \
    -c 'lua assert(require("jdtls"))' -c 'qa!'
$ echo $?
0
```

Exit 0 — `require("jdtls")` succeeds after editing a java file (the `ft =
'java'` lazy-load fires on the buffer edit). `set noswapfile` avoids a stale
swap-file prompt left over from T11's crashed headless run (environmental,
not a config issue).

## Summary

All 3 acceptance criteria PASS. `nvim-jdtls` is declared with `ft = 'java'`
lazy-loading, the telescope `jdt://` URI monkeypatch is in place, and jdtls
loads headless when a java buffer is opened. Full attach behavior (workspace
cache, DAP wiring, organize-imports/test keymaps) is verified in task-10
(static) and task-11 (live attach) evidence.