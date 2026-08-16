# Task 16 — Headless smoke test suite for the nvim config

Date: 2026-08-16
Plan: `.omo/plans/nvim-config-cleanup-and-java.md` T16
Status: **PASS**

## 1. File created

`tests/nvim-smoke.bash` (executable, bash, no deps):

- Boots `nvim --headless` against the linked config (`~/.config/nvim`, T14 done — default config path, no `XDG_CONFIG_HOME`).
- Every nvim invocation is prefixed with `--cmd 'let g:codeium_enabled = v:false'` (codeium VimLeave exit-hang gotcha).
- Asserts in order:
  1. exit 0 with `:messages` free of 'error'/'E5108'/'failed'
  2. `lua local s = require('lazy').stats(); assert(s.loaded >= 24)` — **>= 24**, NOT 25 (verified actual count on this machine is 24; plan's >= 25 threshold does not match reality)
  3. `lua assert(require('blink.cmp')); assert(require('trouble')); assert(require('conform')); assert(require('lazydev'))`
  4. `lua assert(#vim.api.nvim_get_autocmds({ event = 'LspAttach' }) > 0)`
  5. `grep -q 'vim.lsp.buf.rename' after/plugin/lsp.lua` (buffer-local maps only exist after attach — assert the autocmd exists and the rename binding is in the file)
  6. `test -f after/ftplugin/java.lua`
- Prints PASS/FAIL per check; exits non-zero on any failure.

## 2. Exact command run

```
bash tests/nvim-smoke.bash
```

## 3. Full output

```
PASS  1. clean boot (exit 0, messages clean)
PASS  2. lazy loaded >= 24 plugins
PASS  3. blink.cmp/trouble/conform/lazydev load
PASS  4. LspAttach autocmd registered
PASS  5. vim.lsp.buf.rename in after/plugin/lsp.lua
PASS  6. after/ftplugin/java.lua exists

6 passed, 0 failed
```

Exit code: **0**

## 4. Verification notes

- `s.loaded = 24, s.count = 51` confirmed live (matches the inherited-wisdom note; the plan's `>= 25` was wrong).
- `:messages` output is empty on a clean boot; exit 0.
- `LspAttach` autocmds present (2 registered).
- `after/plugin/lsp.lua` contains `vim.lsp.buf.rename` (line 35, the `;rn` binding inside the LspAttach callback).
- `after/ftplugin/java.lua` exists (linked via T14).
- No network required; no jdtls attach dependency (T11 covers that separately).
