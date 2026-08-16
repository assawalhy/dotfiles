# Task 12 Evidence — nvim-config-cleanup-and-java

**Task:** Install stylua and format all lua files
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (1/1 criterion)

## Acceptance criteria

### 1. `stylua --check --config-path common/.config/nvim/.stylua.toml common/.config/nvim` exits 0

```
$ ~/.local/share/nvim/mason/bin/stylua --check --config-path common/.config/nvim/.stylua.toml common/.config/nvim
$ echo $?
0
```

No output, exit 0 — every lua file under `common/.config/nvim` (init.lua,
`lua/**`, `after/**`) conforms to `.stylua.toml` (160 cols, single quotes,
2-space indent). stylua runs from the mason install
(`~/.local/share/nvim/mason/bin/stylua`).

## Summary

Acceptance criterion PASS. The whole nvim config tree is stylua-clean against
the repo's `.stylua.toml`. Formatting config was not modified (guardrail
respected); nothing outside `common/.config/nvim` was formatted.