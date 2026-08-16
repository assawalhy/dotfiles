# nvim-config-cleanup-and-java - Work Plan

## TL;DR (For humans)

**What you'll get:** Your Neovim config reorganized so each concern has one small file (a 5-line `init.lua` manifest, `lua/config/` for settings/keymaps/autocmds, `lua/plugins/` per feature), modernized LSP (native Neovim keymaps instead of the fragile lspsaga overlay, trouble.nvim for diagnostics, lazydev for Lua), a single fast completion engine (blink.cmp) replacing a 7-plugin stack, and — the big one — real Java support: jdtls (Eclipse's Java language server) wired up with per-project workspaces, Maven/Gradle import, debugging with hot-code-replace, and test running, plus maven/gradle added to your installer.

**Why this approach:** LukeElrod's config wins on structure (one concern per file, declarative `opts` over config functions) and restraint (native LSP APIs over UI overlays, 1 completion plugin over 7) — we adopt those patterns while keeping every feature you already have and every keybinding you already use. Java needs nvim-jdtls rather than lspconfig because Eclipse's server requires per-project workspace folders — the plan wires that correctly (the part LukeElrod's own config is missing).

**What it will NOT do:** It won't change your keybindings' meaning, remove any of your features (DAP, folding, textobjects, competitive programming, file explorer, Codeium, clipboard flow), touch your linker/installer scripts, or add jdtls to the generic LSP auto-start (it only activates for Java files).

**Effort:** Medium (16 tasks, ~5 waves)
**Risk:** Medium - the LSP/completion swap touches daily-driver plugins; mitigated by headless smoke tests, a real Java attach test, and keeping your bindings.
**Decisions to sanity-check:** blink.cmp replaces nvim-cmp (Tab now accepts instead of snippet-jumping); lspsaga's peek windows are replaced by native hover; `gp` now hovers instead of peeking; Java DAP launches via jdtls's own adapter (hot-code-replace on).

---

> TL;DR (machine): Medium effort, Medium risk — restructure nvim config into lua/config/* + per-area plugin files, modernize LSP (vim.lsp.enable, lazydev, drop lspsaga, add trouble), migrate completion to blink.cmp, add full Java support (jdtls + DAP + maven/gradle), polish + headless QA.

## Scope
### Must have
- Restructure `common/.config/nvim/init.lua` (394-line kitchen sink) into a manifest + `lua/config/{lazy,options,keymaps,autocmds}.lua`; move the ~20 inline plugins in init.lua's spec into `lua/plugins/{ui,editor,git}.lua`.
- Modernize LSP: rewrite `lua/plugins/lsp.lua` on lspconfig 1.x API (`vim.lsp.enable` loop, `mason-lspconfig` ensure_installed, lazydev replaces neodev); drop lspsaga entirely; add `lua/plugins/trouble.lua`; move conform to `lua/plugins/conform.lua`; new `after/plugin/lsp.lua` with LspAttach buffer-local native keymaps preserving the user's existing bindings (`;rn`, `;ac`, `gd`, `gr`, `[d`, `]d`, `<leader>dd`, `gtd`, `gp`→hover); fix ufo `K` fallback.
- Migrate completion: `lua/plugins/blink.lua` (blink.cmp 1.x) replaces the 7-plugin nvim-cmp stack; delete `lua/plugins/cmp.lua`; keep friendly-snippets.
- Java support: `maven` + `gradle` in `setup/packages.list` (p2); `jdtls` in mason ensure_installed; `java-debug-adapter` + `java-test` in dap.lua's mason-nvim-dap; `lua/plugins/jdtls.lua` (nvim-jdtls, `ft='java'`); telescope `jdt://` URI monkeypatch; `after/ftplugin/java.lua` with full start_or_attach config (per-project workspace cache, `vim.fs.root`, JDK runtimes, vmargs, lombok hook, `setup_dap` hotcodereplace, organize-imports/test keymaps).
- Polish: stylua format (install via mason), `:Lazy clean` orphans (async.nvim, kotlin.nvim, oil.nvim, refactoring.nvim), refresh lazy-lock.json, link new files via `link-files.bash`, README nvim section, headless smoke test in `tests/`.
- Agent-executed QA with evidence files under `.omo/evidence/task-N-nvim-config-cleanup-and-java.md`.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do NOT change keybinding semantics of existing user bindings (only their implementation: lspsaga → native). New bindings only where old ones had no native equivalent (documented per todo).
- Do NOT touch `lua/plugins/{dap,treesitter,ufo,neotree,telescope,competitest}.lua` except the exact edits specified (dap.lua: ensure_installed addition; ufo.lua: K fallback; telescope.lua: jdt:// patch).
- Do NOT remove user features: DAP, ufo folding, textobjects, competitest, neotree, vgit, codeium, true-zen, clipboard `clip` flow (`vim.o.clipboard` stays commented).
- Do NOT add jdtls to lspconfig or auto-start it for non-java buffers.
- Do NOT revert the user's pre-existing changes (`lua/plugins/lsp.lua` refactoring removal, `lazy-lock.json` updates — already committed in 4b3a4ec) — the T3 rewrite and T13 lockfile refresh supersede them.
- Do NOT modify `link-files.bash`, `setup-os`, or the bats tests.
- Do NOT add new dependencies beyond: blink.cmp, trouble.nvim, lazydev.nvim, nvim-jdtls (plugins); jdtls, java-debug-adapter, java-test, stylua (mason); maven, gradle (apt).
- No AI-slop: no commented-out dead code left behind, no placeholder stubs, no `TODO` markers in shipped files.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after. No unit-test framework exists for the nvim config; verification = headless nvim boots + targeted assertions + stylua + linker audit + evidence files.
- Evidence: `.omo/evidence/task-<N>-nvim-config-cleanup-and-java.md` (one per todo; happy + failure runs with exact commands and outputs).
- Every todo's acceptance criteria are exact commands; every QA scenario names the exact tool + invocation.

## Execution strategy
### Parallel execution waves
- Wave 1 (restructure, parallel): T1 init.lua split, T2 delete autoformat.lua
- Wave 2 (LSP modernization): T3 rewrite lsp.lua, T4 conform+trouble files, T6 blink migration (all parallel) → then T5 after/plugin/lsp.lua + ufo fix (after T3)
- Wave 3 (Java infra, parallel): T7 setup-os packages, T8 dap adapters, T9 jdtls plugin + telescope patch
- Wave 4 (Java wiring, sequential): T10 after/ftplugin/java.lua (after T8+T9) → T11 Java QA sample (after T10)
- Wave 5 (polish, mostly parallel): T12 stylua, T13 Lazy clean + lockfile, T14 link files, then T15 README + T16 smoke test (after T12/T13/T14)

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| T1 init.lua split | — | T14, T16 | T2 |
| T2 delete autoformat.lua | — | — | T1 |
| T3 rewrite lsp.lua | — | T5 | T4, T6 |
| T4 conform+trouble | — | — | T3, T6 |
| T5 after/plugin/lsp.lua + ufo fix | T3 | — | — |
| T6 blink.cmp migration | — | T13 | T3, T4 |
| T7 setup-os maven+gradle | — | — | T8, T9 |
| T8 dap java adapters | — | T10 | T7, T9 |
| T9 jdtls plugin + telescope patch | — | T10 | T7, T8 |
| T10 after/ftplugin/java.lua | T8, T9 | T11 | — |
| T11 Java QA sample | T10 | — | — |
| T12 stylua format | T1-T10 | T15, T16 | T13, T14 |
| T13 Lazy clean + lockfile | T6 | T15, T16 | T12, T14 |
| T14 link new files | T1, T3, T4, T5, T6, T9, T10 | T16 | T12, T13 |
| T15 README nvim section | T12, T13 | — | T16 |
| T16 headless smoke test | T12, T13, T14 | — | T15 |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Split init.lua into lua/config/* + move inline plugins to lua/plugins/{ui,editor,git}.lua
  What to do / Must NOT do:
  - Create `common/.config/nvim/lua/config/lazy.lua`: move the bootstrap from init.lua:6-18; modernize `vim.loop.fs_stat` → `(vim.uv or vim.loop).fs_stat`; add clone failure check (if `vim.v.shell_error ~= 0` → `vim.api.nvim_echo` error + `vim.fn.getchar()` + `os.exit(1)`, pattern from /tmp/opencode/lukeelrod-nvim/lua/config/lazy.lua:3-15); then `require('lazy').setup({ spec = { { import = 'plugins' } }, install = { colorscheme = { 'onedark' } } })`.
  - Create `lua/config/options.lua`: move ALL `vim.o`/`vim.wo`/`vim.opt` lines from init.lua:281-328 verbatim (hlsearch=false, incsearch=false, number=true, mouse='a', wrap=false, breakindent=true, tabstop/softtabstop/shiftwidth=4, undofile=true, ignorecase=true, smartcase=true, signcolumn='yes', updatetime=250, timeoutlen=300, completeopt='menuone,noselect', termguicolors=true, scrolloff=10, list=true, listchars eol:↴). Keep `vim.o.clipboard` commented exactly as-is.
  - Create `lua/config/keymaps.lua`: move from init.lua:334-384 — CopyBuffer function, `;y`, `;wc`, `gsw`, j/k expr maps, `<C-w><C-q>`/`<C-w>q` bd, `<C-l/h/j/k>` window nav, `;d`/`;c`/`;D`/`;p`, LocalTerm command + `<space>t`; PLUS move bufferline tab keymaps from init.lua:112-117 (`<tab>n/l/h/x/p/P`) and Comment `<C-_>` maps from init.lua:150-151. Keep all `desc` strings.
  - Create `lua/config/autocmds.lua`: move YankHighlight augroup + TextYankPost callback from init.lua:387-394.
  - Create `lua/plugins/ui.lua` with these plugins moved verbatim from init.lua spec (keep their config/opts/keys exactly): onedark (init.lua:73-80), lualine (82-93), bufferline (95-119 — WITHOUT the keymaps, they moved to keymaps.lua), indent-blankline (121-132), nvim-highlight-colors (185-194), todo-comments (196-201), true-zen (155-164).
  - Create `lua/plugins/editor.lua` with: vim-sleuth (21-22), which-key (24-25), codeium (27-31), flash (33-71), Comment (134-153 — WITHOUT the `<C-_>` nmap/xmap lines, moved to keymaps.lua), vim-surround (166-169), nvim-autopairs (171-175), bufdelete (177), vim-visual-multi (179-183), vim-easy-align (203-208), undotree (210-219), move.nvim (222-235), vim-sneak (263-271).
  - Create `lua/plugins/git.lua` with vgit (237-261) verbatim.
  - Rewrite `init.lua` to exactly: mapleader/maplocalleader + `require('config.lazy')` + `require('config.options')` + `require('config.keymaps')` + `require('config.autocmds')` (order matters: lazy first).
  - Must NOT: change any keybinding semantics; do not touch lua/plugins/{lsp,cmp,dap,treesitter,ufo,neotree,telescope,competitest}.lua; do not delete the `{ import = 'plugins' }` mechanism.
  Parallelization: Wave 1 | Blocked by: — | Blocks: T14, T16
  References: common/.config/nvim/init.lua:1-394 (source of all moves); /tmp/opencode/lukeelrod-nvim/lua/config/lazy.lua:1-35 (bootstrap pattern); /tmp/opencode/lukeelrod-nvim/init.lua:1-4 (manifest pattern); common/.config/nvim/.stylua.toml (160 cols, single quotes)
  Acceptance criteria (agent-executable):
  - `grep -c 'vim\.o\.\|vim\.wo\.\|vim\.opt' common/.config/nvim/init.lua` == 0 AND `grep -c 'vim\.keymap\.set' common/.config/nvim/init.lua` == 0 AND `grep -c 'require' common/.config/nvim/init.lua` == 5
  - `nvim --headless -c 'lua local s = require("lazy").stats(); assert(s.loaded >= 20, "plugins not loading: " .. vim.inspect(s))' -c 'qa'` exits 0
  - `nvim --headless -c 'lua assert(vim.fn.maparg(";y", "x") ~= "")' -c 'lua assert(vim.fn.maparg("<tab>l", "n") ~= "")' -c 'qa'` exits 0
  QA scenarios (name the exact tool + invocation): happy: the three commands above, capture output to Evidence .omo/evidence/task-1-nvim-config-cleanup-and-java.md; failure: boot with `nvim --headless -c 'qa'` and `:messages` shows require errors → fix the failing require path, re-run all three.
  Commit: Y | nvim: split init.lua into config/ and per-area plugin files

- [x] 2. Delete lua/plugins/autoformat.lua (kickstart leftover)
  What to do / Must NOT do:
  - `rm common/.config/nvim/lua/plugins/autoformat.lua` (the kickstart.nvim BufWritePre formatter that double-formats with conform's format_on_save).
  - Grep the whole nvim dir for `autoformat` / `KickstartFormat` / `tsserver` references and remove any stragglers.
  - Must NOT: add a replacement formatter — conform (T4) already handles format_on_save with lsp_fallback.
  Parallelization: Wave 1 | Blocked by: — | Blocks: —
  References: common/.config/nvim/lua/plugins/autoformat.lua:1-74 (the file to delete); common/.config/nvim/lua/plugins/lsp.lua:10-32 (conform format_on_save already present)
  Acceptance criteria (agent-executable): `test ! -f common/.config/nvim/lua/plugins/autoformat.lua` AND `grep -rn 'autoformat\|KickstartFormat' common/.config/nvim` returns nothing (exit 1)
  QA scenarios: happy: `nvim --headless -c 'qa'` exit 0 + grep clean, evidence .omo/evidence/task-2-nvim-config-cleanup-and-java.md; failure: if grep finds references, remove them and re-run.
  Commit: Y | nvim: drop kickstart autoformat leftover (double-format conflict with conform)

- [x] 3. Rewrite lua/plugins/lsp.lua on the modern lspconfig 1.x API
  What to do / Must NOT do:
  - Rewrite `common/.config/nvim/lua/plugins/lsp.lua` to exactly this shape:
    - `{ 'williamboman/mason.nvim', opts = {} }`
    - `{ 'williamboman/mason-lspconfig.nvim', opts = { ensure_installed = { 'bashls', 'clangd', 'pyright', 'ts_ls', 'eslint', 'intelephense', 'html', 'lua_ls', 'kotlin_language_server', 'jdtls' }, automatic_enable = false }, dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' } }` — NOTE: do NOT pass `automatic_installation` (removed in mason-lspconfig 2.x). Set `automatic_enable = false` deliberately: v2's default `automatic_enable = true` would auto-`vim.lsp.enable()` jdtls (it has an lspconfig config), starting a broken jdtls instance and conflicting with the after/ftplugin/java.lua `start_or_attach` (T10). Our explicit enable loop (which excludes jdtls) is the single source of truth.
    - `{ 'neovim/nvim-lspconfig', config = function() ... end }` where the config function does: `vim.lsp.config('html', { filetypes = { 'html', 'twig', 'hbs' } })` then `for _, server in ipairs({ 'bashls', 'clangd', 'pyright', 'ts_ls', 'eslint', 'intelephense', 'html', 'lua_ls', 'kotlin_language_server' }) do vim.lsp.enable(server) end` (jdtls deliberately NOT enabled here — it is started by after/ftplugin/java.lua, T10).
    - `{ 'folke/lazydev.nvim', ft = 'lua', opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } } }` (replaces neodev).
  - Must NOT: keep any `Lspsaga`, `neodev`, `refactoring`, `conform`, `lspsaga` references in this file; do NOT call `vim.lsp.config(server, {})` in a loop (redundant with enable); do NOT add jdtls to the enable loop.
  - NOTE: the refactoring.nvim block is already removed (committed in 4b3a4ec) — the rewrite keeps it gone; do not restore it.
  Parallelization: Wave 2 | Blocked by: — | Blocks: T5
  References: common/.config/nvim/lua/plugins/lsp.lua:1-120 (current file, source of servers list + diagnostic config that moves to T5); /tmp/opencode/lukeelrod-nvim/lua/plugins/lsp.lua:1-42 (modern pattern: lazydev, mason, mason-lspconfig opts); /tmp/opencode/lukeelrod-nvim/after/plugin/lsp.lua:59-61 (vim.lsp.enable pattern)
  Acceptance criteria (agent-executable):
  - `grep -rn 'Lspsaga\|neodev\|refactoring\|conform' common/.config/nvim/lua/plugins/lsp.lua` exits 1 (no matches)
  - `grep -oE "'(bashls|clangd|pyright|ts_ls|eslint|intelephense|html|lua_ls|kotlin_language_server)'" common/.config/nvim/lua/plugins/lsp.lua | sort -u | wc -l` == 9 (all 9 servers present in the enable list; jdtls deliberately absent)
  - `nvim --headless -c 'lua assert(require("lazydev"))' -c 'qa'` exits 0
  QA scenarios: happy: commands above + `nvim --headless -c 'qa'` with `:messages` clean, evidence .omo/evidence/task-3-nvim-config-cleanup-and-java.md; failure: boot error mentioning lspconfig/mason → read the error, fix API usage, re-run.
  Commit: Y | nvim: modernize LSP setup (vim.lsp.enable, lazydev, drop lspsaga)

- [x] 4. Create lua/plugins/conform.lua and lua/plugins/trouble.lua
  What to do / Must NOT do:
  - Create `common/.config/nvim/lua/plugins/conform.lua`: `return { 'stevearc/conform.nvim', event = { 'BufReadPre', 'BufNewFile' }, config = function() require('conform').setup { formatters_by_ft = { lua = { 'stylua' }, python = { 'black', 'isort' }, javascript = { 'prettierd', 'prettier' }, go = { 'gofmt', 'goimports' }, shell = { 'beautysh' } }, format_on_save = { lsp_format = 'fallback', timeout_ms = 500 } }; vim.api.nvim_create_user_command('Format', function() require('conform').format { lsp_format = 'fallback', timeout_ms = 500 } end, { desc = 'Format with conform.nvim' }) end }` (formatters_by_ft + :Format command moved from lsp.lua:13-31; NOTE: the user's current lsp.lua uses the OLD `lsp_fallback = true` API — silently ignored by current conform.nvim — fix to `lsp_format = 'fallback'` during the move).
  - Create `common/.config/nvim/lua/plugins/trouble.lua`: `return { 'folke/trouble.nvim', opts = {}, cmd = 'Trouble', keys = { { '<leader>xx', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics (Trouble)' }, { '<leader>xX', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' }, { '<leader>xs', '<cmd>Trouble symbols toggle focus=false<cr>', desc = 'Symbols (Trouble)' }, { '<leader>xL', '<cmd>Trouble loclist toggle<cr>', desc = 'Location List (Trouble)' }, { '<leader>xQ', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List (Trouble)' } } }` (pattern from /tmp/opencode/lukeelrod-nvim/lua/plugins/trouble.lua:1-39).
  - Must NOT: keep conform inside lsp.lua (T3 removed it); do not add trouble keymaps elsewhere.
  Parallelization: Wave 2 | Blocked by: — | Blocks: —
  References: common/.config/nvim/lua/plugins/lsp.lua:10-32 (conform source); /tmp/opencode/lukeelrod-nvim/lua/plugins/trouble.lua:1-39 (trouble pattern)
  Acceptance criteria (agent-executable): both files exist AND `nvim --headless -c 'lua assert(require("conform")); assert(require("trouble"))' -c 'qa'` exits 0
  QA scenarios: happy: command above, evidence .omo/evidence/task-4-nvim-config-cleanup-and-java.md; failure: require error → check plugin names/opts shape, re-run.
  Commit: Y | nvim: add trouble.nvim, move conform to own plugin file

- [x] 5. Create after/plugin/lsp.lua (LspAttach native keymaps) and fix ufo K fallback
  What to do / Must NOT do:
  - Create `common/.config/nvim/after/plugin/lsp.lua` containing:
    - Diagnostic signs + `vim.diagnostic.config { virtual_text = true, underline = false, update_in_insert = false, severity_sort = true }` moved verbatim from lsp.lua:57-69.
    - A capabilities helper: `local function get_capabilities() local ok, blink = pcall(require, 'blink.cmp'); if ok then return blink.get_lsp_capabilities() end; local caps = vim.lsp.protocol.make_client_capabilities(); caps.textDocument.completion.completionItem.snippetSupport = true; return caps end` (blink may not be loaded yet — pcall fallback).
    - An `LspAttach` autocmd (group `nvim_lsp_attach`, clear=true) that skips clients named 'copilot' and sets BUFFER-LOCAL keymaps preserving the user's bindings with native implementations: `;rn` → `vim.lsp.buf.rename`, `;ac` → `vim.lsp.buf.code_action`, `gd` → `vim.lsp.buf.definition`, `gp` → `vim.lsp.buf.hover` (desc 'LSP: [P]eek/hover', replaces lspsaga peek_definition), `gtd` → `vim.lsp.buf.type_definition`, `gr` → `vim.lsp.buf.references`, `[d` → `vim.diagnostic.jump { count = -1, float = true }`, `]d` → `vim.diagnostic.jump { count = 1, float = true }`. Keep the exact `desc` strings from lsp.lua:72-82.
    - Global (non-buffer) map: `<leader>dd` → `vim.diagnostic.setloclist` (desc 'LSP: Open diagnostics list').
  - Edit `common/.config/nvim/lua/plugins/ufo.lua:94-100`: replace `vim.cmd [[ Lspsaga hover_doc ]]` with `vim.lsp.buf.hover()` (uncomment the existing `-- vim.lsp.buf.hover()` line and delete the Lspsaga line).
  - Must NOT: change the user's keybinding semantics (only implementation); do not add LukeElrod's keymap set; do not map `K` (ufo owns it). NOTE: `gtp` (lspsaga peek_type_definition) has no native equivalent — it is deliberately dropped; `gtd` covers type definition navigation.
  Parallelization: Wave 2 | Blocked by: T3 | Blocks: —
  References: common/.config/nvim/lua/plugins/lsp.lua:56-82 (keymaps + diagnostic config source); common/.config/nvim/lua/plugins/ufo.lua:94-100 (K fallback); /tmp/opencode/lukeelrod-nvim/after/plugin/lsp.lua:1-22 (LspAttach pattern)
  Acceptance criteria (agent-executable):
  - `grep -rn 'Lspsaga' common/.config/nvim` exits 1 (zero references anywhere)
  - `nvim --headless -c 'lua assert(#vim.api.nvim_get_autocmds({ event = "LspAttach" }) > 0)' -c 'qa'` exits 0
  QA scenarios: happy: commands above, evidence .omo/evidence/task-5-nvim-config-cleanup-and-java.md; failure: LspAttach autocmd missing → check after/plugin path is on runtimepath (it is, config root is), re-run.
  Commit: Y | nvim: native LSP keymaps via LspAttach, drop lspsaga references

- [x] 6. Migrate completion to blink.cmp
  What to do / Must NOT do:
  - Create `common/.config/nvim/lua/plugins/blink.lua`: `return { 'saghen/blink.cmp', version = '1.*', opts = { keymap = { preset = 'default' }, appearance = { nerd_font_variant = 'mono' }, completion = { documentation = { auto_show = true, auto_show_delay_ms = 500 }, list = { selection = { preselect = true, auto_insert = false } } }, sources = { default = { 'lsp', 'path', 'buffer', 'snippets' } }, fuzzy = { implementation = 'prefer_rust_with_warning' } } }` — NOTE: `keymap = { preset = 'default' }` with NO overrides, because blink's default preset already matches the user's cmp muscle memory exactly (C-n/C-p select, C-b/C-f scroll docs, C-Space show, CR accept, Tab/S-Tab snippet forward/backward). Do NOT copy LukeElrod's C-k/C-j/Tab-accept overrides — that would change the user's bindings.
  - Delete `common/.config/nvim/lua/plugins/cmp.lua`.
  - Keep `friendly-snippets` (blink's snippets provider auto-loads it — no config needed).
  - Must NOT: keep nvim-cmp/LuaSnip/cmp-nvim-lsp/cmp_luasnip/lspkind/telescope-luasnip anywhere in lua/plugins/; do not add a LuaSnip dependency.
  Parallelization: Wave 2 | Blocked by: — | Blocks: T13
  References: /tmp/opencode/lukeelrod-nvim/lua/plugins/blink.lua:1-47 (proven config); common/.config/nvim/lua/plugins/cmp.lua:1-96 (file to delete)
  Acceptance criteria (agent-executable):
  - `test ! -f common/.config/nvim/lua/plugins/cmp.lua` AND `grep -rn 'nvim-cmp\|LuaSnip\|lspkind\|cmp_luasnip\|cmp-nvim-lsp' common/.config/nvim/lua/plugins/` exits 1
  - `nvim --headless -c 'lua assert(require("blink.cmp"))' -c 'qa'` exits 0
  QA scenarios: happy: commands above, evidence .omo/evidence/task-6-nvim-config-cleanup-and-java.md; failure: blink require error → check version pin/opts shape, re-run.
  Commit: Y | nvim: replace nvim-cmp stack with blink.cmp

- [x] 7. Add maven and gradle to setup/packages.list
  What to do / Must NOT do:
  - Append two lines to `setup/packages.list`: `maven p2` and `gradle p2` (apt names on Ubuntu; no per-manager override needed — verify `apt-cache policy maven gradle` shows candidates; if gradle is missing from apt on this distro, use `gradle aur:gradle` style override per the file's syntax documented in README.md).
  - Must NOT: add jdk entries (JDK 21 already installed); do not touch setup-os script.
  Parallelization: Wave 3 | Blocked by: — | Blocks: —
  References: setup/packages.list (format documented in README.md 'Installing programs' section); README.md:150-165 (packages.list syntax)
  Acceptance criteria (agent-executable): `grep -n '^maven\|^gradle' setup/packages.list` shows both with p2 AND `./setup-os --list 2>/dev/null | grep -iE 'maven|gradle'` shows both
  QA scenarios: happy: commands above, evidence .omo/evidence/task-7-nvim-config-cleanup-and-java.md; failure: setup-os --list doesn't show them → check tier token placement (must be last token before comment), re-run.
  Commit: Y | setup: add maven and gradle to p2 tier

- [x] 8. Add java debug/test adapters to dap.lua
  What to do / Must NOT do:
  - Edit `common/.config/nvim/lua/plugins/dap.lua:34-36`: change `require('mason-nvim-dap').setup { automatic_setup = true,` to `require('mason-nvim-dap').setup { ensure_installed = { 'javadbg', 'javatest' }, automatic_setup = true,` (keep the cppdbg handler untouched). NOTE: mason-nvim-dap's API takes DAP ADAPTER names, not mason package names — `javadbg`→java-debug-adapter, `javatest`→java-test (mapping in lua/mason-nvim-dap/mappings/source.lua). Using the package names would fail to install.
  - Must NOT: change any DAP keymaps or the cppdbg handler; do not add java configurations here (jdtls.setup_dap in T10 generates them).
  Parallelization: Wave 3 | Blocked by: — | Blocks: T10
  References: common/.config/nvim/lua/plugins/dap.lua:34-88 (setup block)
  Acceptance criteria (agent-executable): `grep -c 'javadbg\|javatest' common/.config/nvim/lua/plugins/dap.lua` == 2 AND `nvim --headless -c 'MasonInstall java-debug-adapter java-test' -c 'qa'` exits 0 AND `ls ~/.local/share/nvim/mason/packages | grep -c java` == 2
  QA scenarios: happy: commands above, evidence .omo/evidence/task-8-nvim-config-cleanup-and-java.md; failure: mason install fails → check registry availability, retry once, report.
  Commit: Y | nvim: install java debug/test adapters via mason

- [x] 9. Add nvim-jdtls plugin and telescope jdt:// URI patch
  What to do / Must NOT do:
  - Create `common/.config/nvim/lua/plugins/jdtls.lua`: `return { 'mfussenegger/nvim-jdtls', ft = 'java' }`.
  - Edit `common/.config/nvim/lua/plugins/telescope.lua` config function (after `require('telescope').setup(...)` at line 16-32, before the keymaps): add the monkeypatch from /tmp/opencode/lukeelrod-nvim/lua/plugins/telescope.lua:25-38 — `local utils = require('telescope.utils'); local orig_is_uri = utils.is_uri; utils.is_uri = function(filename) if filename:match('^jdt://') then return false end; return orig_is_uri(filename) end` with the `--monkeypatch for jdtls` comment.
  - Must NOT: change telescope setup opts or keymaps; do not add jdtls config here (T10).
  Parallelization: Wave 3 | Blocked by: — | Blocks: T10
  References: /tmp/opencode/lukeelrod-nvim/lua/plugins/telescope.lua:25-38 (patch); common/.config/nvim/lua/plugins/telescope.lua:15-49 (insertion point)
  Acceptance criteria (agent-executable): `grep -c 'jdt://' common/.config/nvim/lua/plugins/telescope.lua` == 1 AND `grep -c 'nvim-jdtls' common/.config/nvim/lua/plugins/jdtls.lua` == 1 AND `nvim --headless -c 'edit /tmp/opencode/java-qa-sample/src/main/java/com/example/Hello.java' -c 'lua assert(require("jdtls"))' -c 'qa!'` exits 0 (requires T11's sample project to exist first — if not, create a throwaway /tmp/opencode/Hello.java first)
  QA scenarios: happy: commands above, evidence .omo/evidence/task-9-nvim-config-cleanup-and-java.md; failure: require('jdtls') fails → check ft='java' lazy-loading and that the file was edited before require.
  Commit: Y | nvim: add nvim-jdtls and telescope jdt:// URI patch

- [x] 10. Create after/ftplugin/java.lua with full jdtls config
  What to do / Must NOT do:
  - Create `common/.config/nvim/after/ftplugin/java.lua` with EXACTLY this logic:
    1. `local jdtls = require('jdtls')` (loaded via ft='java' from T9).
    2. Resolve binary: `local mason_jdtls = vim.fn.stdpath('data') .. '/mason/packages/jdtls/bin/jdtls'; local jdtls_bin = vim.fn.filereadable(mason_jdtls) == 1 and mason_jdtls or vim.fn.exepath('jdtls'); if jdtls_bin == '' then vim.notify('jdtls not found — run :MasonInstall jdtls', vim.log.levels.WARN); return end`. NOTE: the mason `bin/jdtls` wrapper script handles the `-configuration` arg internally — do NOT pass `-configuration` in `cmd` (only `-data`).
    3. Root: `local root = vim.fs.root(0, { '.git', 'mvnw', 'pom.xml', 'gradlew', 'settings.gradle', 'settings.gradle.kts', 'build.gradle', 'build.gradle.kts' }); if not root then return end`.
    4. Workspace: `local workspace = vim.fn.stdpath('cache') .. '/jdtls/workspace/' .. vim.fn.fnamemodify(root, ':t'); vim.fn.mkdir(workspace, 'p')`.
    5. Capabilities: same pcall blink helper as after/plugin/lsp.lua (T5) — duplicate the 4-line helper locally.
    6. `local config = { cmd = { jdtls_bin, '-data', workspace }, root_dir = root, capabilities = caps, settings = { java = { configuration = { runtimes = { { name = 'JavaSE-21', path = '/usr/lib/jvm/default-java', default = true } }, updateBuildConfiguration = 'automatic', maven = { downloadSources = true }, gradle = { nestedProjects = true, isAutoRefreshEnabled = true } }, eclipse = { downloadSources = true }, jdt = { ls = { vmargs = '-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Dsun.zip.disableMemoryMapping=true -Xmx1G -Xms100m' .. (os.getenv('LOMBOK_JAR') and (' -javaagent:' .. os.getenv('LOMBOK_JAR')) or '') } } } }, on_attach = function(client, bufnr) jdtls.setup_dap({ hotcodereplace = 'auto' }); vim.keymap.set('n', '<leader>oi', function() jdtls.organize_imports() end, { buffer = bufnr, desc = 'Java: organize imports' }); vim.keymap.set('n', '<leader>ot', function() jdtls.test_class() end, { buffer = bufnr, desc = 'Java: run test class' }); vim.keymap.set('n', '<leader>om', function() jdtls.test_nearest_method() end, { buffer = bufnr, desc = 'Java: run nearest test' }) end }`.
    7. `jdtls.start_or_attach(config)`.
  - Must NOT: add jdtls to lspconfig or vim.lsp.enable; do not hardcode a user-specific path (use /usr/lib/jvm/default-java which exists on this machine — verify with `ls /usr/lib/jvm/default-java`); do not add formatting settings (eclipse default formatter).
  Parallelization: Wave 4 | Blocked by: T8, T9 | Blocks: T11
  References: /tmp/opencode/lukeelrod-nvim/lua/plugins/lsp.lua:41 (plugin); nvim-jdtls README conventions (start_or_attach, setup_dap, organize_imports, test_class/test_nearest_method); common/.config/nvim/after/plugin/lsp.lua (T5, capabilities helper to duplicate)
  Acceptance criteria (agent-executable): file exists AND `grep -c 'start_or_attach' common/.config/nvim/after/ftplugin/java.lua` == 1 AND `grep -c 'setup_dap' common/.config/nvim/after/ftplugin/java.lua` == 1 AND `ls /usr/lib/jvm/default-java` succeeds
  QA scenarios: happy: T11's headless attach test passes; failure: jdtls not attached → check binary path resolution and root detection, re-run T11.
  Commit: Y | nvim: full jdtls config for java files

- [x] 11. Java QA: sample Maven project + headless attach verification
  What to do / Must NOT do:
  - Create `/tmp/opencode/java-qa-sample/` (OUTSIDE the repo): `pom.xml` (maven-compiler-plugin with `<release>21</release>`, junit-jupiter 5.10 dependency), `src/main/java/com/example/Hello.java` (a class with a method + a TODO comment), `src/test/java/com/example/HelloTest.java` (one passing test).
  - Run: `nvim --headless -c 'edit /tmp/opencode/java-qa-sample/src/main/java/com/example/Hello.java' -c 'sleep 60' -c 'lua local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients()); assert(vim.tbl_contains(names, "jdtls"), "jdtls not attached: " .. vim.inspect(names))' -c 'lua local dap = require("dap"); assert(dap.configurations.java and #dap.configurations.java > 0, "no java dap configs")' -c 'qa!'` — capture full output.
  - Write evidence file with the output + `ls ~/.local/share/nvim/mason/packages | grep -E 'jdtls|java'`.
  - Must NOT: commit the sample project (it lives in /tmp/opencode); do not run this against the user's real projects.
  Parallelization: Wave 4 | Blocked by: T10 | Blocks: —
  References: /tmp/opencode/java-qa-sample (created here); common/.config/nvim/after/ftplugin/java.lua (T10)
  Acceptance criteria (agent-executable): evidence file contains 'jdtls not attached' absent AND contains the attached-client assertion passing (exit 0)
  QA scenarios: happy: attach + dap configs asserted, evidence .omo/evidence/task-11-nvim-config-cleanup-and-java.md; failure: timeout/not attached → increase sleep to 90, check `:messages` for jdtls errors, verify mason jdtls package installed, re-run.
  Commit: N (evidence only)

- [x] 12. Install stylua and format all lua files
  What to do / Must NOT do:
  - `nvim --headless -c 'MasonInstall stylua' -c 'qa'` (or `which stylua` first — if already installed, skip).
  - Run `stylua --config-path common/.config/nvim/.stylua.toml common/.config/nvim` to format ALL lua files (init.lua, lua/**, after/**).
  - Re-run `stylua --check --config-path common/.config/nvim/.stylua.toml common/.config/nvim` until exit 0.
  - Must NOT: change formatting config (.stylua.toml stays 160 cols/single quotes); do not format files outside common/.config/nvim.
  Parallelization: Wave 5 | Blocked by: T1-T10 | Blocks: T15, T16
  References: common/.config/nvim/.stylua.toml (config); common/.config/nvim (target)
  Acceptance criteria (agent-executable): `stylua --check --config-path common/.config/nvim/.stylua.toml common/.config/nvim` exits 0
  QA scenarios: happy: check passes, evidence .omo/evidence/task-12-nvim-config-cleanup-and-java.md; failure: check fails → run stylua (not --check) to fix, re-check.
  Commit: Y | nvim: stylua format

- [x] 13. Lazy clean orphans + refresh lazy-lock.json
  What to do / Must NOT do:
  - `nvim --headless -c 'Lazy! clean' -c 'qa'` (removes async.nvim, kotlin.nvim, oil.nvim, refactoring.nvim — installed but no longer in config).
  - `nvim --headless -c 'Lazy! sync' -c 'qa'` (updates lazy-lock.json: blink.cmp added, nvim-cmp/LuaSnip/cmp-*/lspkind/telescope-luasnip removed).
  - Verify: `ls ~/.local/share/nvim/lazy` contains no async.nvim/kotlin.nvim/oil.nvim/refactoring.nvim; `grep -c 'blink.cmp' common/.config/nvim/lazy-lock.json` == 1; `grep -c 'nvim-cmp' common/.config/nvim/lazy-lock.json` == 0.
  - Must NOT: run `Lazy clean` before T6 (would remove nothing harmful but lockfile churn); do not hand-edit lazy-lock.json.
  Parallelization: Wave 5 | Blocked by: T6 | Blocks: T15, T16
  References: common/.config/nvim/lazy-lock.json (target); common/.config/nvim/lua/plugins/ (source of truth)
  Acceptance criteria (agent-executable): the three verification commands above all pass
  QA scenarios: happy: commands pass, evidence .omo/evidence/task-13-nvim-config-cleanup-and-java.md; failure: lockfile still has nvim-cmp → re-run Lazy! sync, check network, re-run.
  Commit: Y | nvim: prune orphaned plugins, refresh lockfile

- [x] 14. Link new files into ~/.config/nvim
  What to do / Must NOT do:
  - From repo root: `./link-files.bash --dry-run '.*nvim.*'` (preview), then `./link-files.bash --yes '.*nvim.*'` (links lua/config/*, lua/plugins/{ui,editor,git,blink,jdtls,conform,trouble}.lua, after/plugin/lsp.lua, after/ftplugin/java.lua). NOTE: `~/.config/nvim` is per-file symlinked (NOT a directory symlink) — new files are NOT live until this step runs; it is mandatory, not optional.
  - Verify: `./link-files.bash --audit` exits 0 AND `ls -la ~/.config/nvim/lua/config ~/.config/nvim/after/plugin ~/.config/nvim/after/ftplugin` shows symlinks into the repo.
  - Must NOT: use --force (no conflicts expected — new paths); do not link files outside common/.config/nvim.
  Parallelization: Wave 5 | Blocked by: T1, T3, T4, T5, T6, T9, T10 | Blocks: T16
  References: link-files.bash (usage in README.md 'Linking' section); common/.config/nvim (new files)
  Acceptance criteria (agent-executable): `./link-files.bash --audit` exits 0 AND `readlink ~/.config/nvim/lua/config/options.lua` contains 'dotfiles/common/.config/nvim'
  QA scenarios: happy: audit clean + symlinks verified, evidence .omo/evidence/task-14-nvim-config-cleanup-and-java.md; failure: audit exit 1 → read the report, link missing files, re-run.
  Commit: N (linker state only)

- [x] 15. README: document nvim config structure and Java setup
  What to do / Must NOT do:
  - Add a '## Neovim' section to `README.md` (after the Layout table area): structure overview (init.lua manifest → lua/config/{lazy,options,keymaps,autocmds}.lua → lua/plugins/*.lua → after/plugin/lsp.lua → after/ftplugin/java.lua), the LSP keymap table (;rn, ;ac, gd, gp, gtd, gr, [d, ]d, <leader>dd), blink.cmp keys (C-n/C-p select, C-b/C-f scroll, C-Space complete, CR accept, Tab/S-Tab snippet jump), and Java requirements (JDK 21+, maven/gradle via `./setup-os --priority p2`, mason packages jdtls/java-debug-adapter/java-test, lombok via LOMBOK_JAR env var, per-project workspace cache location).
  - Must NOT: duplicate the whole keymap list from other sections; keep it concise (≤ 60 lines).
  Parallelization: Wave 5 | Blocked by: T12, T13 | Blocks: —
  References: README.md (existing structure); the final state of common/.config/nvim (T1-T10)
  Acceptance criteria (agent-executable): `grep -c '## Neovim' README.md` == 1 AND `grep -c 'LOMBOK_JAR' README.md` == 1
  QA scenarios: happy: greps pass, evidence .omo/evidence/task-15-nvim-config-cleanup-and-java.md; failure: section missing → re-check content, re-run.
  Commit: Y | docs: document nvim config structure and Java setup

- [x] 16. Headless smoke test suite for the nvim config
  What to do / Must NOT do:
  - Create `tests/nvim-smoke.bash` (executable, bash, no deps): boots `nvim --headless` and asserts in order: (1) exit 0 with `:messages` free of 'error'/'E5108'/'failed', (2) `lua local s = require('lazy').stats(); assert(s.loaded >= 25)`, (3) `lua assert(require('blink.cmp')); assert(require('trouble')); assert(require('conform')); assert(require('lazydev'))`, (4) `lua assert(#vim.api.nvim_get_autocmds({ event = 'LspAttach' }) > 0)`, (5) `lua assert(vim.fn.maparg(';rn', 'n') ~= '')` (buffer-local maps only exist after attach — instead assert the autocmd exists and `grep -q 'vim.lsp.buf.rename' after/plugin/lsp.lua`), (6) `test -f after/ftplugin/java.lua`. Prints PASS/FAIL per check, exits non-zero on any failure.
  - Run it; capture output to evidence.
  - Must NOT: require network; do not make it depend on jdtls attaching (too slow for a smoke test — T11 covers that).
  Parallelization: Wave 5 | Blocked by: T12, T13, T14 | Blocks: —
  References: tests/helpers.bash (existing test conventions); common/.config/nvim (final state)
  Acceptance criteria (agent-executable): `bash tests/nvim-smoke.bash` exits 0
  QA scenarios: happy: all PASS, evidence .omo/evidence/task-16-nvim-config-cleanup-and-java.md; failure: any FAIL → fix the underlying config issue, re-run.
  Commit: Y | test: add nvim headless smoke test

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit — every todo's acceptance criteria re-run against the final tree; evidence files exist for all 16 todos; no scope creep (diff shows only the files named in the plan).
- [x] F2. Code quality review — read every changed/created lua file: no dead code, no Lspsaga/neodev/nvim-cmp remnants, no stubs, stylua-clean, desc on every keymap, no commented-out blocks left behind.
- [x] F3. Real manual QA — boot nvim interactively (tmux), open a java file from the sample project, verify: jdtls attaches (`:LspInfo`), completion pops (blink), `;rn`/`;ac`/`gd` work, `:Trouble` opens, `:Format` works, `:Mason` shows jdtls/java-debug-adapter/java-test installed.
- [x] F4. Scope fidelity — user's feature set intact (DAP, ufo, textobjects, competitest, neotree, vgit, codeium, clipboard clip flow); keybinding semantics unchanged; dirty-worktree user changes not reverted; nothing outside common/.config/nvim + setup/packages.list + README.md + tests/nvim-smoke.bash modified.

## Commit strategy
- One commit per todo (16 commits), repo style: lowercase prefix + short summary (see `git log --oneline`: 'nvim: ...', 'setup: ...', 'docs: ...', 'test: ...').
- Commit lines are specified per todo. Evidence files (.omo/evidence/) are NOT committed (repo convention: .omo/ is partially tracked — check `git status`; commit only the config files named in each todo).
- The user's pre-existing uncommitted changes (lsp.lua refactoring removal, lazy-lock.json) are absorbed by T3/T13 commits — never committed separately.
- Do NOT commit /tmp/opencode/java-qa-sample.

## Success criteria
- `init.lua` is a ≤ 15-line manifest; every concern has one home file.
- Zero references to Lspsaga, neodev, nvim-cmp, LuaSnip, lspkind, refactoring.nvim, autoformat/KickstartFormat in common/.config/nvim.
- blink.cmp, trouble.nvim, lazydev.nvim load; LspAttach buffer-local keymaps active; ufo K hovers natively.
- jdtls attaches to Java files (headless-verified), java DAP configurations exist, organize-imports/test keymaps bound.
- maven + gradle in setup/packages.list p2; jdtls/java-debug-adapter/java-test/stylua in mason.
- `stylua --check` clean; `:Lazy clean` pruned orphans; lazy-lock.json consistent; `link-files.bash --audit` exit 0; `tests/nvim-smoke.bash` passes.
- README documents the nvim structure and Java requirements.
