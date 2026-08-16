# Task 5 Evidence — nvim-config-cleanup-and-java

**Task:** Create after/plugin/lsp.lua (LspAttach native keymaps) and fix ufo K fallback
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (3/3 criteria)

## Acceptance criteria

### 1. `grep -rn 'Lspsaga' common/.config/nvim` exits 1 (zero references anywhere)

```
$ grep -rn 'Lspsaga' common/.config/nvim
$ echo $?
1
```

No output, exit 1 — zero `Lspsaga` references in the whole nvim config. The
lspsaga plugin file and all its call sites are gone (T3 removed the plugin,
this todo removed the last `hover_doc` call site in ufo.lua).

### 2. LspAttach autocmd registered

```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless \
    --cmd 'let g:codeium_enabled = v:false' \
    -c 'lua assert(#vim.api.nvim_get_autocmds({ event = "LspAttach" }) > 0)' -c 'qa'
$ echo $?
0
```

Exit 0 — at least one `LspAttach` autocmd is registered at boot (the
`nvim_lsp_attach` group from `after/plugin/lsp.lua`).

### 3. ufo K fallback + fold keymaps preserved

```
$ grep -n 'vim.lsp.buf.hover\|zR\|zM\|zr' common/.config/nvim/lua/plugins/ufo.lua
    84: vim.keymap.set('n', 'zR', require('ufo').openAllFolds, { desc = 'Open all folds' })
    85: vim.keymap.set('n', 'zM', require('ufo').closeAllFolds, { desc = 'Close all folds' })
    86: vim.keymap.set('n', 'zr', require('ufo').openFoldsExceptKinds, { desc = 'Open folds except kinds' })
    90: vim.lsp.buf.hover()
```

- Line 90: the `K` fallback now calls `vim.lsp.buf.hover()` (the `Lspsaga
  hover_doc` line is deleted) — native hover, no lspsaga.
- Lines 84-86: `zR`/`zM`/`zr` fold keymaps preserved with their `desc`s.

## Summary

All 3 acceptance criteria PASS. `after/plugin/lsp.lua` registers the
`LspAttach` autocmd (group `nvim_lsp_attach`, buffer-local native keymaps
`;rn`/`;ac`/`gd`/`gp`/`gtd`/`gr`/`[d`/`]d` + global `<leader>dd`), and
ufo.lua's `K` fallback hovers natively. Zero `Lspsaga` references remain in
the config. Headless boot with `XDG_CONFIG_HOME` pointed at the repo (pre-T14
link state) + codeium disabled (VimLeave exit-hang workaround) exits 0.