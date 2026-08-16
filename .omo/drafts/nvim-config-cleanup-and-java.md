---
slug: nvim-config-cleanup-and-java
status: drafting
intent: clear
pending-action: write .omo/plans/nvim-config-cleanup-and-java.md
approach: <fill: the approach you intend to plan>
---

# Draft: nvim-config-cleanup-and-java

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->

## Findings (cited - path:lines)

## Decisions (with rationale)

## Scope IN

## Scope OUT (Must NOT have)

## Open questions

## Approval gate
status: drafting
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
# Draft: nvim config cleanup + modern LSP + Java support

status: awaiting-approval
pending action: write .omo/plans/nvim-config-cleanup-and-java.md
approach: 5 waves (restructure → LSP modernization → blink.cmp → Java → polish/QA) as briefed below
decisions: blink.cmp migrate ✓ | drop lspsaga → native + trouble ✓ | Java build tools BOTH maven+gradle ✓

## Request
1. What did LukeElrod/nvim do better than my config?
2. How to make my configs cleaner?
3. How to better configure LSP, especially Java support?

## Environment facts (verified 2026-08-15)
- Neovim **v0.12.3** (all modern APIs available: vim.lsp.config, vim.lsp.enable, lazydev)
- `~/.config/nvim` fully symlinked into dotfiles repo `common/.config/nvim` (init.lua, .stylua.toml, snippets/, lua/plugins/* all linked)
- lazy.nvim with `{ import = 'plugins' }` — already modular via `lua/plugins/*.lua` (12 files, ~1400 LOC)
- **JDK 21 present** (openjdk-21, `/usr/bin/javac`), **NO maven, NO gradle, NO jdtls**
- mason packages installed: bashls, beautysh, black, clangd, cpptools, eslint-lsp, html-lsp, intelephense, kotlin-lsp, ktfmt, ktlint, lua_ls, mypy, prettier, pyright, shellcheck, ts_ls — **no Java anything**
- `setup/packages.list` + `setup/steps/*.sh`: **no java/maven/gradle entries**
- tests/ = only link-files.bats (no nvim config tests)
- stylua config: 160 cols, single quotes

## Findings on user config (paths)
- `init.lua` (394 lines): kitchen sink — bootstrap + full plugin list + options + keymaps + autocmds + CopyBuffer/LocalTerm functions mixed together. 6 explicit `config = function()` blocks inside the spec.
- `lua/plugins/lsp.lua`: **mixed-generation LSP API**: old `mason_lspconfig.setup { ensure_installed, automatic_installation }` + `vim.lsp.config()` loop without `vim.lsp.enable`; lspsaga for ALL LSP UI; neodev (deprecated); conform nested as lspconfig dependency.
- `lua/plugins/autoformat.lua`: **kickstart.nvim leftover** — BufWritePre `vim.lsp.buf.format` per-client → **double-formatting conflict** with conform's `format_on_save = { lsp_fallback = true }`. Also references `tsserver` name (outdated; it's `ts_ls`).
- `lua/plugins/cmp.lua`: 7-plugin completion stack (nvim-cmp, cmp-nvim-lsp, LuaSnip, cmp_luasnip, friendly-snippets, telescope-luasnip, lspkind) + dead `unpack = unpack or table.unpack` line + commented-out mapping blocks.
- `lua/plugins/ufo.lua`: `K` keymap falls back to `Lspsaga hover_doc` (breaks if lspsaga dropped).
- Not in config but installed / in lockfile: refactoring.nvim (in lazy-lock, no config file); live lazy dir has async.nvim, kotlin.nvim, oil.nvim, trouble.nvim NOT in lockfile (removed-from-config leftovers → `:Lazy clean`).
- Bootstrap uses deprecated `vim.loop.fs_stat` (no `(vim.uv or vim.loop)` fallback) and no clone error check (clone failure silently continues → rtp prepend of missing path).
- `;y`/`;wc` clipboard via custom `clip` binary (works; `vim.o.clipboard = 'unnamedplus'` deliberately commented).
- DAP: solid (nvim-dap + dap-ui + mason-nvim-dap, C++ cppdbg configs). No Java DAP.

## Findings on LukeElrod/nvim (paths in /tmp/opencode/lukeelrod-nvim)
- `init.lua` = 4 requires: `config.lazy`, `opts`, `autocmds`, `keymaps` — one concern per file.
- `lua/config/lazy.lua`: bootstrap + `vim.g.mapleader` before lazy + clone error check (`vim.v.shell_error` → echo + getchar + os.exit(1)).
- Plugin files nearly all `opts = {}` (declarative, lazy auto-setup); `opts_extend` in blink.lua for modular extension; config functions are the exception (telescope monkeypatch, minimal).
- `after/plugin/lsp.lua`: LspAttach autocmd → **buffer-local** native keymaps (`vim.lsp.buf.hover/rename/code_action/declaration`, telescope builtins for defs/refs/impls/workspace-symbols, `vim.diagnostic.jump`), plus `vim.lsp.config`/`vim.lsp.enable` for dartls/ts_ls/roslyn_ls (modern API), per-server `on_attach` setting tabstop, custom cmd for roslyn.
- `lua/plugins/lsp.lua`: lazydev (lua), lspconfig + blink dep, mason with extra registry, mason-lspconfig `opts={}`, **nvim-jdtls** plugin.
- `lua/plugins/telescope.lua`: **jdt:// URI monkeypatch** `utils.is_uri` (jdtls returns jdt:// URIs that break telescope pickers).
- `lua/plugins/blink.lua`: blink.cmp 1 plugin replaces the whole cmp stack; `opts_extend` pattern.
- trouble.nvim for diagnostics; gitsigns; oil; toggleterm; nvim-notify; copilot.lua; tree-sitter-manager.
- autocmds.lua: checktime on FocusGained/BufEnter/CursorHold/TermLeave (AI-file reload); help filetype auto `only`.
- README documents all default keymaps.
- **Caveat (fairness)**: no DAP at all, no folding, no textobjects, no which-key — smaller feature surface. And his jdtls is **also incomplete**: plugin + telescope patch present, but NO `ftplugin/java.lua` / `start_or_attach` call anywhere → his jdtls never actually starts. Git history: single commit (shallow clone).

## What LukeElrod does better (Q1 answer)
1. Structure: one concern per file; init.lua is a 4-line manifest.
2. Declarative lazy idioms: `opts = {}` + `opts_extend` data over functions.
3. Native modern LSP over UI-overlay plugin (no lspsaga): LspAttach buffer-local maps, vim.lsp.config/enable, trouble for lists.
4. Dependency discipline: 1 completion plugin vs 7; lighter load, fewer breakages.
5. Java awareness: nvim-jdtls + telescope jdt:// patch (the two non-obvious pieces; wiring still missing).
6. API hygiene: vim.uv, clone error check, docs in README.
(What user does better: DAP, folding, textobjects, CP setup, far superior dotfiles tooling layer.)

## Planned approach (Q2+Q3) — waves
- W1 Restructure: init.lua → lua/config/{lazy,options,keymaps,autocmds}.lua; move global keymaps out of plugin configs; dead code removal; vim.uv; clone error check; drop autoformat.lua (double-format conflict); opts-ify config functions; desc everywhere.
- W2 LSP modernization: rewrite lsp.lua (mason-lspconfig ensure_installed + vim.lsp.enable loop, lazydev for lua); after/plugin/lsp.lua LspAttach buffer-local keymaps; conform → own file; trouble.nvim (pending answer); ufo K fix.
- W3 Completion: blink.cmp migration (pending answer) or cmp cleanup.
- W4 Java: setup-os +maven(+jdk); mason jdtls + java-debug-adapter + java-test; nvim-jdtls plugin; after/ftplugin/java.lua (cmd via mason path, per-project cache workspace, vim.fs.root, java.configuration.runtimes, setup_dap hotcodereplace, capabilities); telescope jdt:// patch; lombok hook; sample-project QA.
- W5 Polish: stylua, :Lazy clean leftovers, lockfile, README nvim section, headless smoke tests.

## Open forks (asked user 2026-08-15)
1. Completion engine: blink.cmp migrate vs keep nvim-cmp
2. lspsaga: drop (native + trouble) vs keep
3. Java build tool: maven / gradle / both / none — shapes setup-os + test project