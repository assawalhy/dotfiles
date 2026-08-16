# Task 4 — Create lua/plugins/conform.lua and lua/plugins/trouble.lua

Plan: `.omo/plans/nvim-config-cleanup-and-java.md` task 4.

## What was done

- Created `common/.config/nvim/lua/plugins/conform.lua` — conform.nvim moved out of
  lsp.lua into its own plugin file. `formatters_by_ft` (lua/stylua, python/black+isort,
  javascript/prettierd+prettier, go/gofmt+goimports, shell/beautysh), `format_on_save`
  with `lsp_format = 'fallback'` (current API — the old `lsp_fallback = true` from the
  source lsp.lua was silently ignored by current conform.nvim and was NOT copied), and
  the `:Format` user command.
- Created `common/.config/nvim/lua/plugins/trouble.lua` — `opts = {}`, `cmd = 'Trouble'`,
  5 `<leader>x*` keys (xx/xX/xs/xL/xQ), pattern from lukeelrod-nvim.
- Linked both into the live config: `./link-files.bash --yes '.*nvim.*'` from repo root.
  Verified symlinks:
  - `~/.config/nvim/lua/plugins/conform.lua -> /home/ms/myp/dotfiles/common/.config/nvim/lua/plugins/conform.lua`
  - `~/.config/nvim/lua/plugins/trouble.lua -> /home/ms/myp/dotfiles/common/.config/nvim/lua/plugins/trouble.lua`

## Acceptance criteria

1. Both files exist:

```
$ test -f common/.config/nvim/lua/plugins/conform.lua && test -f common/.config/nvim/lua/plugins/trouble.lua && echo "FILES_EXIST=OK"
FILES_EXIST=OK
```

2. `nvim --headless -c 'lua assert(require("conform")); assert(require("trouble"))' -c 'qa'` exits 0.

The assertions pass (both plugins load). NOTE: a plain `qa` hangs at exit because of an
environmental issue — codeium.vim's `VimLeave` hook calls `codeium#ServerLeave()`, which
blocks when the codeium language server is not reachable. This affects EVERY headless nvim
boot in this session (parallel tasks T3/T6 hit the identical hang), so it is not caused by
these files. With codeium disabled before plugins load, the exact acceptance command exits 0:

```
$ nvim --headless --cmd 'let g:codeium_enabled = v:false' -c 'lua assert(require("conform")); assert(require("trouble"))' -c 'qa'; echo "ACCEPTANCE_EXIT=$?"
ACCEPTANCE_EXIT=0
```

Direct assertion proof (boot completes, both requires succeed, exit path forced):

```
$ timeout 25 nvim --headless -c 'lua assert(require("conform")); assert(require("trouble")); print("ASSERTS_OK")' -c 'lua vim.cmd("qa!")'
ASSERTS_OK
```

## Result

PASS. Both files created with the exact plan content, linked into the live config, and
both plugins load headless. The only deviation from the literal acceptance command is the
`--cmd 'let g:codeium_enabled = v:false'` prefix, required to work around the
environmental codeium `VimLeave` exit-hang that blocks all parallel nvim boots this session.
