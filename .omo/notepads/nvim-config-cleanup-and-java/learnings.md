
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

## [2026-08-16] F2 rejection fix — desc + commented-out cleanup (Sisyphus)

- Added `desc` to all 19 `vim.keymap.set` calls in `lua/config/keymaps.lua` (wrapped-line j/k, tabnew/BufferLine x6, window focus x4, no-yank delete/change x7) and 4 in `lua/plugins/ufo.lua` (zR/zM/zr + K hover fallback — K's desc goes on the closing `end,` of the function form).
- Deleted 12 commented-out blocks: keymaps.lua 4 zz-maps, dap.lua nvim-dap-go dep + dap-go setup call, treesitter.lua rainbow2 dep + 3 foldmethod lines, ufo.lua provider_selector block (incl. its `-- INFO:` line — F2 counts it as part of the commented-out block) + close_fold_kinds + winhighlight, neotree.lua lsp-file-operations block, telescope.lua fzf.vim block, competitest.lua output_compare_method.
- KEPT `options.lua:12 -- vim.o.clipboard = 'unnamedplus'` (plan-mandated intentional comment) — it is now the ONLY match for the F2 commented-out-code grep, which is the expected end state.
- Lazy `keys` descs added (F2 non-blocking rec): true-zen x5 (descs match actual keys zn/zf/zm/za, NOT the task's guessed zt/zz/zZ/zn/zN), vim-surround x4 (ds/cs/ys/S), easy-align ga, undotree U, move.nvim x8 (line/selection × down/up/left/right), sneak x4 (actual keys are f/F/t/T, not s/S).
- Verification: stylua --check whole dir PASS (160col/single-quote config), grep for commented-out code matches ONLY options.lua:12, headless boot with XDG_CONFIG_HOME + codeium disabled exits 0.
- NOTE for future F2-style greps: the `^\s*--\s*['"]` pattern also matches doc comments quoting plugin names (e.g. `-- NOTE: 'kevinhwang91/nvim-ufo' now handles it` in treesitter.lua) — those are documentation, not dead code, and were kept.

## [2026-08-16] F1 evidence backfill — T5-T10, T12-T15 (Sisyphus)

- Backfilled the F1 evidence-gap finding: created `.omo/evidence/task-{5,6,7,8,9,10,12,13,14,15}-nvim-config-cleanup-and-java.md` (10 files). All 16 todos now have evidence files. HEAD at backfill: `5c4bf98`.
- All acceptance criteria re-run against the current tree — **16/16 PASS** (10 re-verified here + 6 existing files). No config/setup/README/test files touched; no commits.
- **T9 headless gotcha:** editing `/tmp/opencode/java-qa-sample/.../Hello.java` headless hit a stale swap-file prompt (E325) left over from T11's crashed run (`~/.local/state/nvim/swap/%tmp%opencode%...swp`). Exit was still 0 (`qa!`), but for clean evidence prefix `-c 'set noswapfile'` before `-c 'edit ...'`. Environmental, not a config issue.
- **T8 count note:** `ls ~/.local/share/nvim/mason/packages | grep -c java` == 2 counts only java-debug-adapter + java-test; jdtls is installed too (T3) but doesn't match the `java` pattern — the criterion's count of 2 is exact as specified.
- **T14 audit:** `--audit '.*nvim.*'` exits 0 with "Audit clean (58 links correct)". Full unfiltered audit's only finding remains the x11-neglected `.xinitrc` (wayland session) — expected, no nvim drift. `readlink ~/.config/nvim/lua/config/options.lua` → `/home/ms/myp/dotfiles/common/.config/nvim/lua/config/options.lua` (per-file symlink live).
- **T13 lockfile:** blink.cmp pinned at commit `78336bc8` (branch main); nvim-cmp fully absent. Orphaned plugins (async.nvim, kotlin.nvim, oil.nvim, refactoring.nvim) confirmed gone from `~/.local/share/nvim/lazy`.
- **T12:** stylua from mason (`~/.local/share/nvim/mason/bin/stylua`) `--check` clean against `.stylua.toml` (160 cols/single quotes) — whole `common/.config/nvim` tree, exit 0.

## [2026-08-16] F2 RE-RUN — APPROVE (Sisyphus)

- Re-ran all 7 MUST-DO criteria after the REJECT fixes. All PASS → verdict APPROVE written to `.omo/evidence/f2-code-quality.txt` (overwrote the REJECT file, same format).
- Fixes verified: 50/50 `vim.keymap.set` calls have desc (script count per file: keymaps 25/25, ufo 4/4, telescope 8/8, lsp.lua 9/9, java.lua 3/3, dap 1/1 via nvmap wrapper whose 15 invocations all pass desc strings). Runtime maparg asserts for ufo zR/K descs pass after `require('lazy').load({plugins={'nvim-ufo'}})`.
- Commented-out grep now matches ONLY `options.lua:12` (intentional, plan-mandated). All 12 blocks confirmed deleted by full-file reads.
- Lazy `keys` descs verified in all files: true-zen x5, flash x5, comment x2, vim-surround x4, easy-align x1, undotree x1, move.nvim x8, sneak x4, treesj x4, competitest x8, trouble x5, neotree x1.
- Boot sanity: XDG_CONFIG_HOME + codeium-disabled headless boot exits 0 with >= 20 plugins loaded.
- NOTE: the F2 fixes are UNCOMMITTED working-tree changes (10 modified files, HEAD still 5c4bf98). Evidence header documents this. Someone must commit before F3/F4 final sign-off or the fixes could be lost.
- dap.lua desc-count gotcha for future scripted checks: the nvmap wrapper's local `desc = 'Dap: ' .. desc` assignment makes naive `desc =` counting report 2 descs for 1 keymap call — count per-call, not per-file, or special-case wrappers.

## [2026-08-16] F3 manual QA executed — all 6 items PASS (Sisyphus)

- Ran the F3 REAL manual QA gate interactively in tmux (session f3qa) on /tmp/opencode/java-qa-sample with the live ~/.config/nvim. Verdict APPROVE, evidence at .omo/evidence/f3-manual-qa.txt (overwrote the link-context-filter plan's file, per task).
- **`:LspInfo` does NOT exist on this build** — E492. Root cause: nvim-lspconfig plugin/lspconfig.lua lines 5-7 `if vim.fn.exists(':lsp') == 2 then return end` — nvim 0.11+ has the builtin `:lsp` command, so lspconfig skips defining LspInfo/LspLog/etc. The documented replacement `:checkhealth vim.lsp` shows the same active-client info (jdtls id 1, root /tmp/opencode/java-qa-sample, JavaSE-21 at /usr/lib/jvm/default-java). Future QA/plan acceptance criteria should use `:checkhealth vim.lsp` or `vim.lsp.get_clients()` instead of `:LspInfo`.
- **blink.cmp completion is context-aware via jdtls**: typing `System.` inside main() offered out/err/in (PrintStream/InputStream) + methods with signatures; typing at TOP LEVEL (outside the class body) offered declaration keywords (abstract/class/enum/sealed/...) — that's jdtls correctly answering per position, not a bug. When testing completion, type INSIDE a method.
- **blink ghost-text display artifact**: with the completion popup open, capture-pane can show the selected item's text rendered after the cursor, making the line look longer than `getline()` reports. Ground truth = `getline()`/`complete_info()`, not the pane render.
- **`:Trouble` opens a mode picker first** (Diagnostics/fzf/loclist/lsp/...); `:Trouble diagnostics` opens the diagnostics tree directly. It listed the jdtls TODO diagnostic at [9, 12].
- **`:Format` functionally verified**: introduced `return    "Hello, "` (extra spaces) via nvim_buf_set_lines, ran `:Format`, line restored to single space. conform lsp_format fallback -> jdtls works.
- **Mason UI**: jdtls/java-debug-adapter/java-test all installed (22 packages total), confirmed both in `:Mason` UI and on disk.
- **Stale swap file from the aborted F3 run** was present on the sample file; deleted with 'd' at the E325 prompt. If F3 ever aborts again, clean ~/.local/state/nvim/swap/%tmp%opencode%... before re-running.
- gd functional jump verified: 14:40 (greet call) -> 8:19 (greet definition). ;rn -> vim.lsp.buf.rename, ;ac -> vim.lsp.buf.code_action, gd -> vim.lsp.buf.definition, all with descs.

## [2026-08-16] Rainbow2 re-enabled — user-requested follow-up (Sisyphus)

- Re-added `HiPhish/nvim-ts-rainbow2` to treesitter.lua: dependency line after autotag + `rainbow = { enable = true, extended_mode = true, max_file_lines = 1000 }` block between highlight and incremental_selection. stylua --check clean (160col/single-quote), no other files touched, no commit.
- Lazy sync cloned it (branch master, commit b3120cd5) and wrote the lockfile entry through to `common/.config/nvim/lazy-lock.json` — intended per README.
- **MODULE NAME GOTCHA:** the plugin's Lua module is `ts-rainbow`, NOT `nvim-ts-rainbow2` — `require("nvim-ts-rainbow2")` fails with E5108 even though the plugin is installed and working. Verify with `require("ts-rainbow")` (exit 0). The task's suggested acceptance require name was wrong; the plugin itself is fine.
- Acceptance: grep counts 1/2 pass, stylua exit 0, sync exit 0, `require("ts-rainbow")` exit 0, lockfile grep == 1.

## [2026-08-16] setup-os `check:<command>` token added (Sisyphus)

- Added `check:<cmd>` token support to `setup/packages.list` + `setup-os` so packages installed outside the manager (tarball/cargo/snap, differently-named apt packages) are detected as installed. Files: `setup-os`, `setup/packages.list`, `README.md`. No commit.
- **Resolver** (`resolve()` awk): `check` var parsed in the token loop BEFORE the generic `m[substr($i,1,p-1)]` assignment — a `check:` token must NOT land in the manager map `m` (it has a colon, so the generic branch would have stored `m["check"]="bat"`). Emitted as 6th tab field: `group \t id \t mgr \t pkg \t prio \t check`. cargo/pip special-case also emits the 6th field (empty when absent).
- **Menu loop**: `read -r group id mgr pkg prio check`; package branch: `pm_installed` stays primary, then `[ -z "$state" ] && [ -n "$check" ] && command -v "$check"` sets ` (installed)`. Steps emit 5 fields → `check` reads empty, unaffected.
- **Downstream consumers verified with 6 fields**: `--group` ($1), `--priority` ($5 — prio stays field 5), `only_list` ($1 $2 $5 $3 $4), PICKED round-trip ($1|$2|$3|$4) all unchanged and working.
- **Real-case verification**: on this machine dpkg DOES see a `bat` package (so bat is caught by the manager lookup, not the fallback), but neovim is genuinely invisible to dpkg (`dpkg-query -W` has no neovim) — `check:nvim` + `/opt/nvim-linux-x86_64/bin/nvim` on PATH hid it via the fallback. Menu-loop simulation: neovim SKIPPED via check fallback, bat SKIPPED, entries without check behave normally (pipx/texlive still offered).
- **Design note**: `check:` is single-token, command name only — no spaces/args (e.g. `check:command -v bat` invalid). Multi-word checks would need a different mechanism (steps already support full shell via `# check:` headers). `--all`/`--priority` intentionally keep installed entries in the menu (pre-existing behavior), so the picker-filter test must simulate the menu loop without `want_all`.

## [2026-08-16] check: audit — 25 entries tagged for out-of-manager installs (Sisyphus)

- Extended `setup/packages.list` with `check:<cmd>` on 25 entries commonly installed OUTSIDE the package manager, so setup-os hides them from the picker when the binary exists on PATH even when the manager can't see it. Only `setup/packages.list` modified; `setup-os` untouched (`bash -n` clean). No commit.
- **Binary-name gotchas**: `git-delta` → `check:delta` (binary is `delta`), `maven` → `check:mvn` (binary is `mvn`). Both are cargo/tarball/sdkman installs where the package id ≠ the command.
- **Sections covered**: [extra] gh/git-delta/yt-dlp/pandoc/glow/gitui/lazygit (tarball/script/cargo), [gui] syncthing/obsidian/typora/megasync (tarball/AppImage), [dev] lldb (Xcode CLT)/maven/gradle (sdkman), [terminal] fzf (git-clone script)/fd (tarball), [cargo] fastmod/eza/broot/rmem/sd (tarball bypasses `cargo install --list`), [pip] git-fame/autopep8/black/mdtoc (system-pip bypasses `pipx list`).
- **Deliberately NOT tagged**: packages always installed via the manager (git, zsh, tmux, ranger, pipx, mousepad, xsel, xclip, wl-clipboard, luarocks, ffmpeg, texlive, mpv, copyq, zathura, zathura-pdf-mupdf, okular, feh, skim, pngpaste, docker, meld, bats, noto-fonts-*, libxft-bgra).
- **Alignment convention**: id column padded to width 20; comment column at 53 (pN ends at 51); lines without comments use single-space token separation (bat style). `check:` token goes BEFORE the `pN` token.
- **Verification**: resolver awk simulation (same logic as `resolve()`) run with os=linux pm=apt, os=linux pm=pacman, os=macos pm=brew — all 25 new entries emit the check field as the 6th tab field (megasync only resolves on cask, as expected: `pacman:- apt:- dnf:-`).
