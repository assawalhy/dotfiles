# Task 3 — Rewrite lua/plugins/lsp.lua on the modern lspconfig 1.x API

Plan: `.omo/plans/nvim-config-cleanup-and-java.md` todo 3
Date: 2026-08-16
Status: PASS

## What changed

`common/.config/nvim/lua/plugins/lsp.lua` rewritten from the 120-line kitchen-sink
(lspsaga + neodev + conform + diagnostic config + keymaps + `vim.lsp.config` loop)
to the exact 3-plugin shape in the plan:

1. `{ 'williamboman/mason.nvim', opts = {} }`
2. `{ 'williamboman/mason-lspconfig.nvim', opts = { ensure_installed = { 10 servers incl. jdtls }, automatic_enable = false }, dependencies = { mason.nvim, nvim-lspconfig } }`
   - `automatic_enable = false` (v2 default true would auto-enable jdtls → conflict with T10's ftplugin start_or_attach)
   - `automatic_installation` NOT passed (removed in mason-lspconfig 2.x)
3. `{ 'neovim/nvim-lspconfig', config = function() ... end }`:
   - `vim.lsp.config('html', { filetypes = { 'html', 'twig', 'hbs' } })`
   - `for _, server in ipairs({ 9 servers }) do vim.lsp.enable(server) end` (jdtls deliberately excluded — T10 owns it)
4. `{ 'folke/lazydev.nvim', ft = 'lua', opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } } }` (replaces neodev)

Diagnostic config + keymaps moved OUT (they belong to T5's after/plugin/lsp.lua).
symbols-outline.nvim plugin entry dropped (not in plan's shape).

## Acceptance criteria (all PASS)

### 1. No forbidden references
```
$ grep -rn 'Lspsaga\|neodev\|refactoring\|conform' common/.config/nvim/lua/plugins/lsp.lua
(no output)
grep exit: 1   ✅
```

### 2. All 9 servers in the enable list (jdtls absent)
```
$ grep -oE "'(bashls|clangd|pyright|ts_ls|eslint|intelephense|html|lua_ls|kotlin_language_server)'" common/.config/nvim/lua/plugins/lsp.lua | sort -u | wc -l
9   ✅
```

### 3. lazydev loads
```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless -c 'lua assert(require("lazydev"))' -c 'qa'
lazydev exit: 0   ✅
```

### 4. Clean headless boot, :messages empty
```
$ XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless -c 'lua local m = vim.api.nvim_exec2("messages", { output = true }).output; assert(m == "", "messages not clean: " .. m)' -c 'qa'
clean-boot exit: 0   ✅
```

Note: acceptance run with `XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config`
per T1 learning — `~/.config/nvim` is per-file symlinked and new files aren't live
until T14 links them; this boots the repo config exactly as post-link.

## Failure runs (for the record)

- First two boots timed out (120s / 600s): mason-lspconfig `ensure_installed`
  triggered a first-boot install of all 10 servers (jdtls ~100MB) AND T4/T6 run
  the same config in parallel, so multiple nvim instances fought over the shared
  `~/.local/share/nvim/mason` staging dir. Once all 10 servers were installed
  (`ls ~/.local/share/nvim/mason/packages` shows jdtls/ etc.) and the parallel
  boots finished, the acceptance commands pass in isolation. Not a config bug —
  environmental first-install concurrency.

## Stylua

`stylua` not installed yet (T12 installs it). Longest line = 147 chars (< 160-col
limit in .stylua.toml), single quotes throughout — matches the plan's exact shape.

## Files touched

- `common/.config/nvim/lua/plugins/lsp.lua` (rewritten)
- `.omo/evidence/task-3-nvim-config-cleanup-and-java.md` (this file, not committed)
