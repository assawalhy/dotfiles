#!/usr/bin/env bash
#
# nvim-smoke.bash -- headless smoke test for the nvim config.
#
# Boots `nvim --headless` against the linked config (~/.config/nvim) and
# asserts, in order:
#   1. exit 0 with :messages free of 'error'/'E5108'/'failed'
#   2. lazy has loaded >= 24 plugins
#   3. blink.cmp, trouble, conform, lazydev all require() cleanly
#   4. an LspAttach autocmd is registered
#   5. after/plugin/lsp.lua binds vim.lsp.buf.rename (buffer-local maps only
#      exist after attach, so assert the autocmd + the binding source)
#   6. after/ftplugin/java.lua exists
#
# Every nvim invocation is prefixed with `--cmd 'let g:codeium_enabled = v:false'`
# because codeium.vim's VimLeave hook blocks nvim exit when its server is
# unreachable -- without it headless nvim hangs on exit.
#
# Prints PASS/FAIL per check; exits non-zero on any failure.

set -u

CONFIG_DIR="${NVIM_SMOKE_CONFIG_DIR:-$HOME/.config/nvim}"

pass=0
fail=0

# run_nvim <args...> -- nvim --headless with the codeium-disable prefix
run_nvim() {
  nvim --headless --cmd 'let g:codeium_enabled = v:false' "$@"
}

check() { # <name> <result(0/1)> <detail>
  local name="$1" ok="$2" detail="$3"
  if [ "$ok" -eq 0 ]; then
    printf 'PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$name"
    [ -n "$detail" ] && printf '      %s\n' "$detail"
    fail=$((fail + 1))
  fi
}

# --- 1. clean boot: exit 0 + messages free of error/E5108/failed -----------
boot_out="$(run_nvim -c 'messages' -c 'qa' 2>&1)"
boot_status=$?
if [ "$boot_status" -eq 0 ] && ! grep -qiE 'error|E5108|failed' <<< "$boot_out"; then
  check '1. clean boot (exit 0, messages clean)' 0 ''
else
  check '1. clean boot (exit 0, messages clean)' 1 "exit=$boot_status messages: $(printf '%s' "$boot_out" | tr '\n' ' ' | head -c 300)"
fi

# --- 2. lazy loaded >= 24 ---------------------------------------------------
if run_nvim -c 'lua local s = require("lazy").stats(); assert(s.loaded >= 24)' -c 'qa' >/dev/null 2>&1; then
  check '2. lazy loaded >= 24 plugins' 0 ''
else
  check '2. lazy loaded >= 24 plugins' 1 ''
fi

# --- 3. core plugins require() ----------------------------------------------
if run_nvim -c 'lua assert(require("blink.cmp")); assert(require("trouble")); assert(require("conform")); assert(require("lazydev"))' -c 'qa' >/dev/null 2>&1; then
  check '3. blink.cmp/trouble/conform/lazydev load' 0 ''
else
  check '3. blink.cmp/trouble/conform/lazydev load' 1 ''
fi

# --- 4. LspAttach autocmd registered ----------------------------------------
if run_nvim -c 'lua assert(#vim.api.nvim_get_autocmds({ event = "LspAttach" }) > 0)' -c 'qa' >/dev/null 2>&1; then
  check '4. LspAttach autocmd registered' 0 ''
else
  check '4. LspAttach autocmd registered' 1 ''
fi

# --- 5. rename binding present in after/plugin/lsp.lua -----------------------
if grep -q 'vim.lsp.buf.rename' "$CONFIG_DIR/after/plugin/lsp.lua"; then
  check '5. vim.lsp.buf.rename in after/plugin/lsp.lua' 0 ''
else
  check '5. vim.lsp.buf.rename in after/plugin/lsp.lua' 1 "missing in $CONFIG_DIR/after/plugin/lsp.lua"
fi

# --- 6. after/ftplugin/java.lua exists ---------------------------------------
if [ -f "$CONFIG_DIR/after/ftplugin/java.lua" ]; then
  check '6. after/ftplugin/java.lua exists' 0 ''
else
  check '6. after/ftplugin/java.lua exists' 1 "missing: $CONFIG_DIR/after/ftplugin/java.lua"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
