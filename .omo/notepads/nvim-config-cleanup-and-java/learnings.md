
## API DRIFT VERIFICATION — 2026-08-15 (pre-flight research)

Verified against current plugin docs/source (context7 + GitHub raw + mason-registry).

### VERDICTS

| # | Plugin | Claim | Status |
|---|--------|-------|--------|
| 1a | blink.cmp | keymap preset 'default' + command names | MATCH (one binding error, see below) |
| 1b | blink.cmp | appearance.nerd_font_variant='mono' | MATCH |
| 1c | blink.cmp | completion.documentation/list.selection shape | MATCH |
| 1d | blink.cmp | sources.default = {lsp,path,buffer,snippets} | MATCH |
| 1e | blink.cmp | fuzzy.implementation='prefer_rust_with_warning' | MATCH |
| 1f | blink.cmp | blink.get_lsp_capabilities() | MATCH |
| 1g | blink.cmp | snippets auto-loads friendly-snippets | MATCH (friendly_snippets=true is default) |
| 2 | trouble.nvim | opts={} + cmd='Trouble' + filter.buf=0 keys | MATCH (v3 current, 3.7.1) |
| 3 | lazydev.nvim | library ${3rd}/luv + words vim%.uv + ft='lua' | MATCH (exact README match) |
| 4a | mason-lspconfig | ensure_installed in opts | MATCH (v2) |
| 4b | mason-lspconfig | automatic_installation removed | CONFIRMED REMOVED (v2.0.0, 2025-05-06) |
| 4c | mason-lspconfig | 10 server names | ALL VALID (ts_ls confirmed via registry) |
| 5 | nvim-jdtls | start_or_attach/setup_dap/organize_imports/test_class/test_nearest_method | ALL MATCH |
| 6 | conform.nvim | format_on_save = { lsp_fallback = true, ... } | **CHANGED → lsp_format = "fallback"** |
| 7 | mason-nvim-dap | ensure_installed = {'java-debug-adapter','java-test'} | **CHANGED → {'javadbg','javatest'}** |

### DISCREPANCIES TO FIX IN PLAN

1. **blink.cmp keymap binding error**: plan says scroll_documentation_down/up = C-d/C-f.
   ACTUAL default preset: `<C-b>` = scroll_documentation_up, `<C-f>` = scroll_documentation_down.
   C-d is NOT bound in the default preset. Fix plan text to C-b/C-f.
   (C-n/C-p=select, C-Space=show, CR=accept, Tab/S-Tab=snippet all correct.)

2. **conform.nvim**: `lsp_fallback = true` is the OLD pre-2024 API. Current:
   `format_on_save = { timeout_ms = 500, lsp_format = "fallback" }`
   (lsp_format ∈ "fallback" | "never" | "best_effort"). Old key is silently ignored.

3. **mason-nvim-dap**: uses DAP ADAPTER names, not mason package names (README explicit).
   Correct: `ensure_installed = { 'javadbg', 'javatest' }`
   (source.lua: javadbg→java-debug-adapter, javatest→java-test).

### NOTES / BEHAVIOR CHANGES

- mason-lspconfig v2 requires Neovim 0.11+, Mason v2, nvim-lspconfig v2. `automatic_enable = true` is DEFAULT → installed servers auto `vim.lsp.enable()`; explicit lspconfig setup may be redundant for migrated servers. handlers/setup_handlers also removed.
- trouble v3 (2024-05-30) is a full rewrite; auto_open/auto_close removed. Plan's usage is v3-compatible.
- nvim-jdtls README now also documents native `vim.lsp.enable("jdtls")` path; start_or_attach still fully supported. eclipse.jdt.ls requires Java 21.
- blink.cmp default preset also binds <C-e>=hide/fallback, <C-y>=select_and_accept, <C-k>=show_signature, <Up>/<Down>=select_prev/next.

## [2026-08-15] Pre-flight synthesis (Atlas)

### Environment checks (passed)
- Neovim v0.12.3, `vim.lsp.enable` available → satisfies mason-lspconfig v2 (0.11+) requirement.
- JDK 21.0.11 at /usr/lib/jvm/default-java (symlink → java-1.21.0-openjdk-amd64). T10 path valid.
- apt has maven 3.8.7-2 and gradle 4.4.1-20 candidates. NOTE: gradle 4.4.1 is ancient (2018) — fine for the Maven-based QA sample, but flag to user for real Gradle projects.
- mason packages: NO jdtls/java-debug-adapter/java-test yet (T3 ensure_installed + T8 install them). kotlin-lsp IS installed but never enabled → T3's kotlin_language_server addition is correct.
- stylua NOT installed → T12 installs via mason.
- link-files.bash --audit: exit 1 but ONLY finding is `.xinitrc` neglected (x11 context, we're on wayland) — expected, no nvim drift.

### Live config (explore agent): ALL 14 line citations MATCH, zero drift
- init.lua exactly 394 lines; all plugin/options/keymaps/autocmd ranges verified.
- lsp.lua 120 lines (conform 10-32, diag+keymaps 56-82), ufo.lua 102 (K fallback 94-100), dap.lua 130 (mason-nvim-dap 34-36), telescope.lua 65 (setup 15-49), cmp.lua 96, autoformat.lua 74.
- lua/config/, after/, after/plugin/, after/ftplugin/ DO NOT exist yet — all created by plan.
- 9 plugin files exist: autoformat, cmp, competitest, dap, lsp, neotree, telescope, treesitter, ufo.
- **CORRECTION**: the "uncommitted changes" the plan worried about (refactoring.nvim removal, lazy-lock.json) are ALREADY COMMITTED in 4b3a4ec. Working tree for common/.config/nvim is clean. Plan lines 33/114 updated to say "already committed".

### Reference config (explore agent): jdtls gap CONFIRMED
- LukeElrod declares `{ "mfussenegger/nvim-jdtls" }` in lsp.lua:41 but NEVER configures it (no opts, no vim.lsp.enable("jdtls"), no keymaps). Our T9/T10 wiring is genuinely additive.
- Stale quotes in plan (already handled — plan deliberately deviates): blink sources.default is {"lazydev","lsp","path","buffer"} (we use our own {'lsp','path','buffer','snippets'} since we keep friendly-snippets); mason.nvim opts has icons+Crashdummyy registry (we use opts={}); lazy.lua colorscheme is habamax (we use onedark — user's theme); vim.lsp.enable is 3 individual calls not a loop (our loop is fine); init.lua is requires-only, mapleader in config/lazy.lua (our init.lua sets mapleader — fine, set before lazy loads).

### Plan corrections applied (9 edits)
1. T3: added `automatic_enable = false` to mason-lspconfig opts (v2 default true would auto-enable jdtls → conflict with ftplugin start_or_attach).
2. T3: fixed acceptance criterion — grep -c 'vim.lsp.enable' == 9 was wrong for a loop; now counts the 9 server names in the enable list.
3. T4: conform `lsp_fallback = true` → `lsp_format = 'fallback'` (old API silently ignored).
4. T6: blink scroll docs C-d/C-f → C-b/C-f.
5. T8: mason-nvim-dap ensure_installed {'java-debug-adapter','java-test'} → {'javadbg','javatest'} (DAP adapter names).
6. T8: acceptance criterion grep updated to javadbg/javatest.
7. T15: README blink keys C-d/C-f → C-b/C-f.
8. Lines 33, 114: "uncommitted" → "already committed in 4b3a4ec".

### Verdict: plan is decision-complete and API-current. Ready to execute.

## [2026-08-15] T2 executed — delete autoformat.lua

- Deleted `common/.config/nvim/lua/plugins/autoformat.lua` (74-line kickstart BufWritePre formatter).
- Grep for `autoformat|KickstartFormat|tsserver` across common/.config/nvim: ZERO matches — no stragglers in init.lua or other plugin files.
- **IMPORTANT for T14/linker**: `~/.config/nvim/lua/plugins/autoformat.lua` was a stale per-file symlink into the repo. After deleting the repo file, nvim boot printed `Failed to load plugins.autoformat: cannot open ... No such file or directory` (exit still 0). Removed the stale symlink manually → boot clean. The linker's `--audit`/`--fix` (3de6385) would also catch this, but the live config must not reference the deleted file between T2 and T14.
- Headless boot `nvim --headless -c 'qa'` now exits 0 with zero messages.

## [2026-08-15] T1 execution findings (Sisyphus)

- **Plan discrepancy #1 (acceptance count):** T1 acceptance says `grep -c 'require' init.lua` == 5, but the spec mandates exactly 4 requires (lazy/options/keymaps/autocmds — 4 config files). Actual count: 4. A 5th require would break boot. Spec followed; documented in evidence.
- **Plan gap #2 (pre-link acceptance):** `~/.config/nvim` is per-file symlinked and nvim does NOT resolve the init.lua symlink for the config root — `stdpath('config')` = `~/.config/nvim`, so `require('config.lazy')` fails until T14 links `lua/config/`. `-u <file>` also does NOT add the file's dir to rtp (verified with scratch config). Fix: run acceptance with `XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config` — boots the repo config exactly as post-link, touches nothing outside the repo. T14/T16 must re-verify against the live tree.
- **Vimscript plugins have no Lua module:** vim-surround, vim-sleuth, vim-visual-multi, vim-sneak, vim-easy-align can't be `require()`d — verify via `require('lazy').plugins()` name list instead.
- **lazy stats() shape:** `{ count = 57, loaded = 33, times = {...} }` — no `installed`/`loaded_plugins` fields in this lazy version.
- **Boot result:** 33 plugins loaded at boot (≥ 20 ✓), messages clean, all moved keymaps present (`;y` x-mode, `<tab>l` n-mode).

## [2026-08-16] T3 executed — rewrite lsp.lua (Sisyphus)

- Rewrote `common/.config/nvim/lua/plugins/lsp.lua` to the plan's exact 3-plugin shape: mason.nvim opts={}, mason-lspconfig ensure_installed(10 incl. jdtls) + automatic_enable=false + deps, nvim-lspconfig config fn (vim.lsp.config('html',{filetypes}) + 9-server vim.lsp.enable loop, jdtls excluded), lazydev ft='lua' replacing neodev. Dropped symbols-outline.nvim (not in plan shape). Diagnostic config + keymaps removed (T5's after/plugin/lsp.lua owns them).
- All 4 acceptance criteria PASS (grep exit 1, server count 9, lazydev require exit 0, clean boot + empty :messages exit 0).
- **ENVIRONMENTAL GOTCHA (parallel-wave first boot):** mason-lspconfig ensure_installed triggers a first-boot install of all 10 servers. T3/T4/T6 boot the SAME config in parallel → multiple nvim instances fight over shared ~/.local/share/nvim/mason staging; boots hang (SIGTERM at 120s/600s) until all servers are installed and parallel boots finish. jdtls is the big one (~100MB). NOT a config bug. Mitigation for later waves: if a headless boot hangs, check `pgrep -af 'nvim --headless'` for parallel agents and `ls ~/.local/share/nvim/mason/packages` for missing servers; re-run once installs complete.
- Stylua not installed yet (T12). Longest line 147 < 160 cols, single quotes — file is stylua-clean by inspection.
- Acceptance must use `XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config` (T1 learning) until T14 links the new files.
- T4: Created `lua/plugins/conform.lua` (formatters_by_ft + format_on_save with `lsp_format = 'fallback'` + :Format cmd, moved from lsp.lua) and `lua/plugins/trouble.lua` (opts={}, cmd='Trouble', 5 <leader>x* keys). Linked via `./link-files.bash --yes '.*nvim.*'` (also linked blink.lua from T6, removed stale cmp.lua link). Both require() load headless; acceptance exit 0. Commit e4b1cd0.
- **ENVIRONMENTAL GOTCHA #2 (codeium VimLeave exit-hang):** codeium.vim's `VimLeave` hook calls `codeium#ServerLeave()`, which blocks nvim exit when the codeium language server is unreachable. This hangs EVERY headless `-c 'qa'`/`qa!` in this session (T3/T4/T6 all hit it) — NOT a config bug. Workaround for headless acceptance: prefix `--cmd 'let g:codeium_enabled = v:false'` before the -c assertions; exit 0 cleanly. Do NOT "fix" this in the config (codeium is a user feature, plan says keep it).
