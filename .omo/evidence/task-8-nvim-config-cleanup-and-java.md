# Task 8 Evidence — nvim-config-cleanup-and-java

**Task:** Add java debug/test adapters to dap.lua
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (2/2 criteria)

## Acceptance criteria

### 1. `grep -o 'javadbg\|javatest' common/.config/nvim/lua/plugins/dap.lua | wc -l` == 2

```
$ grep -o 'javadbg\|javatest' common/.config/nvim/lua/plugins/dap.lua | wc -l
2
```

Both DAP adapter names present in the `mason-nvim-dap` `ensure_installed`
list. NOTE: these are the DAP **adapter** names (`javadbg` → java-debug-adapter,
`javatest` → java-test), not mason package names — mason-nvim-dap's API takes
adapter names (mapping in `lua/mason-nvim-dap/mappings/source.lua`).

### 2. `ls ~/.local/share/nvim/mason/packages | grep -c java` == 2

```
$ ls ~/.local/share/nvim/mason/packages | grep -c java
2
$ ls ~/.local/share/nvim/mason/packages | grep java
java-debug-adapter
java-test
```

Both java adapters installed in mason. (`jdtls` is also installed — from T3's
`ensure_installed` — but does not match the `java` grep pattern, so the count
is exactly 2 as specified.)

## Summary

All 2 acceptance criteria PASS. `dap.lua`'s `mason-nvim-dap` setup includes
`ensure_installed = { 'javadbg', 'javatest' }` (count 2), and both
`java-debug-adapter` and `java-test` are installed under
`~/.local/share/nvim/mason/packages`. The cppdbg handler and DAP keymaps were
untouched (guardrail respected). Java DAP *configurations* are generated at
runtime by `jdtls.setup_dap` (T10) — verified attached in task-11 evidence.