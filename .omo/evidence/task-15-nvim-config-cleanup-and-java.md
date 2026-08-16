# Task 15 Evidence — nvim-config-cleanup-and-java

**Task:** README: document nvim config structure and Java setup
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (2/2 criteria)

## Acceptance criteria

### 1. `grep -c '## Neovim' README.md` == 1

```
$ grep -c '## Neovim' README.md
1
```

Exactly one `## Neovim` section (line 36), documenting the config structure:
init.lua manifest → `lua/config/{lazy,options,keymaps,autocmds}.lua` →
`lua/plugins/*.lua` → `after/plugin/lsp.lua` → `after/ftplugin/java.lua`,
plus the LSP keymap table (`;rn`, `;ac`, `gd`, `gp`, `gtd`, `gr`, `[d`, `]d`,
`<leader>dd`) and blink.cmp keys (C-n/C-p select, C-b/C-f scroll docs,
C-Space complete, CR accept, Tab/S-Tab snippet jump).

### 2. `grep -c 'LOMBOK_JAR' README.md` == 1

```
$ grep -c 'LOMBOK_JAR' README.md
1
```

Exactly one `LOMBOK_JAR` mention (line 78): "Lombok support is enabled by
setting `LOMBOK_JAR` to the lombok jar path; the agent is appended to the
jdtls VM args when set." The Java section also covers JDK 21+ requirement,
maven/gradle via `./setup-os --priority p2`, mason packages
(jdtls/java-debug-adapter/java-test), and the per-project workspace cache
under `stdpath('cache')/jdtls/workspace/<project-name>`.

## Summary

All 2 acceptance criteria PASS. README.md has exactly one `## Neovim` section
and exactly one `LOMBOK_JAR` reference, documenting the restructured config
layout and the Java setup (JDK 21+, maven/gradle p2 tier, mason packages,
lombok hook, workspace cache). Section stays concise (≤ 60 lines, guardrail
respected).