# Task 1 Evidence — nvim-config-cleanup-and-java

**Task:** Split init.lua into lua/config/* + move inline plugins to lua/plugins/{ui,editor,git}.lua
**Date:** 2026-08-15
**Commit:** `nvim: split init.lua into config/ and per-area plugin files`

## Files created

- `common/.config/nvim/lua/config/lazy.lua` — bootstrap (modernized `(vim.uv or vim.loop).fs_stat`, clone-failure check with `nvim_echo`/`getchar`/`os.exit(1)`), `require('lazy').setup({ spec = { { import = 'plugins' } }, install = { colorscheme = { 'onedark' } } })`
- `common/.config/nvim/lua/config/options.lua` — all `vim.o`/`vim.wo`/`vim.opt` lines from init.lua:281-328 verbatim (incl. commented `vim.o.clipboard`)
- `common/.config/nvim/lua/config/keymaps.lua` — init.lua:334-384 (CopyBuffer, `;y`, `;wc`, `gsw`, j/k expr, `<C-w><C-q>`/`<C-w>q`, `<C-l/h/j/k>`, `;d`/`;c`/`;D`/`;p`, LocalTerm + `<space>t`) + bufferline tab maps (init.lua:112-117) + Comment `<C-_>` nmap/xmap (init.lua:150-151)
- `common/.config/nvim/lua/config/autocmds.lua` — YankHighlight augroup + TextYankPost (init.lua:387-394)
- `common/.config/nvim/lua/plugins/ui.lua` — onedark, lualine, bufferline (keymaps removed → keymaps.lua), indent-blankline, nvim-highlight-colors, todo-comments, true-zen
- `common/.config/nvim/lua/plugins/editor.lua` — vim-sleuth, which-key, codeium, flash, Comment (nmap/xmap removed → keymaps.lua), vim-surround, nvim-autopairs, bufdelete, vim-visual-multi, vim-easy-align, undotree, move.nvim, vim-sneak
- `common/.config/nvim/lua/plugins/git.lua` — vgit verbatim
- `common/.config/nvim/init.lua` — rewritten to manifest: mapleader/maplocalleader + `require('config.lazy')` + `require('config.options')` + `require('config.keymaps')` + `require('config.autocmds')` (lazy first)

## Acceptance criteria

### 1. grep checks

```
$ grep -c 'vim\.o\.\|vim\.wo\.\|vim\.opt' common/.config/nvim/init.lua
0
$ grep -c 'vim\.keymap\.set' common/.config/nvim/init.lua
0
$ grep -c 'require' common/.config/nvim/init.lua
4
```

First two pass (== 0). Third returns **4, not 5** — see note below.

> **NOTE (plan discrepancy):** The plan's acceptance says `grep -c 'require'` == 5, but the plan's own spec (todo 1 "Rewrite init.lua to exactly: mapleader/maplocalleader + require('config.lazy') + require('config.options') + require('config.keymaps') + require('config.autocmds')") mandates exactly **4** requires — there are exactly 4 config files (lazy/options/keymaps/autocmds). The "5" appears to be a miscount in the plan; the manifest matches the spec verbatim. A 5th require would break boot (no 5th module exists), so the spec was followed.

### 2. lazy stats (plugins loading)

Run with `XDG_CONFIG_HOME` pointed at the repo so the new files are on the runtimepath **before** T14 links them into `~/.config/nvim` (T1 blocks T14; `~/.config/nvim` is per-file symlinked, so `require` resolves against the symlink path until linking):

```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless \
    -c 'lua local s = require("lazy").stats(); assert(s.loaded >= 20, "plugins not loading: " .. vim.inspect(s))' -c 'qa'
$ echo $?
0
```

Detailed stats: `{ count = 57, loaded = 33, ... }` — 33 plugins loaded at boot (≥ 20 ✓).

Per-file plugin verification (all pass, exit 0):

```
ui.lua:     require("onedark"), require("bufferline"), require("lualine"), require("ibl"),
            require("todo-comments"), require("true-zen"), require("nvim-highlight-colors")  → "ui.lua plugins OK"
git.lua:    require("vgit")                                                                   → "git.lua plugins OK"
editor.lua: all 13 specs registered in lazy plugin list (vim-surround, vim-sleuth, vim-visual-multi,
            vim-sneak, vim-easy-align are Vimscript plugins with no Lua module — verified via
            require("lazy").plugins() name list)                                              → "editor.lua spec OK"
```

Boot messages clean: `nvim --headless -c 'lua local m = vim.api.nvim_exec2("messages", {output=true}).output; assert(not m:match("error") and not m:match("E5108") and not m:match("failed"), m)' -c 'qa'` → exit 0.

### 3. keymaps

```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless \
    -c 'lua assert(vim.fn.maparg(";y", "x") ~= "")' \
    -c 'lua assert(vim.fn.maparg("<tab>l", "n") ~= "")' -c 'qa'
$ echo $?
0
```

Both `;y` (visual) and `<tab>l` (normal, bufferline cycle) exist after the move to keymaps.lua.

## Notes

- **Pre-link acceptance:** `~/.config/nvim` is per-file symlinked; `lua/config/` and the new plugin files are not live until T14 (`link-files.bash`). The acceptance was therefore run with `XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config`, which boots the repo config exactly as it will be after linking, without modifying anything outside the repo. T14 will link the files and T16 re-verifies against the live tree.
- **Keybinding semantics unchanged:** every map moved verbatim (same lhs/rhs/mode/desc); only their file location changed. bufferline tab maps and Comment `<C-_>` maps moved to keymaps.lua per spec.
- **`{ import = 'plugins' }` mechanism preserved** (now in lua/config/lazy.lua).
- **Untouched:** lua/plugins/{lsp,cmp,dap,treesitter,ufo,neotree,telescope,competitest}.lua.
- **Formatting:** hand-formatted to .stylua.toml (160 cols, single quotes, 2-space indent); `awk 'length > 160'` over all new files → no violations. stylua itself is installed/run in T12.