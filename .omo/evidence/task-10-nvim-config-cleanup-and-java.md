# Task 10 Evidence — nvim-config-cleanup-and-java

**Task:** Create after/ftplugin/java.lua with full jdtls config
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (4/4 criteria)

## Acceptance criteria

### 1. File exists

```
$ ls common/.config/nvim/after/ftplugin/java.lua
common/.config/nvim/after/ftplugin/java.lua  2.2K
```

### 2. `grep -c 'start_or_attach' common/.config/nvim/after/ftplugin/java.lua` == 1

```
$ grep -c 'start_or_attach' common/.config/nvim/after/ftplugin/java.lua
1
```

Line 66: `jdtls.start_or_attach(config)` — the per-project attach entry point.

### 3. `grep -c 'setup_dap' common/.config/nvim/after/ftplugin/java.lua` == 1

```
$ grep -c 'setup_dap' common/.config/nvim/after/ftplugin/java.lua
1
```

Line 53: `jdtls.setup_dap { hotcodereplace = 'auto' }` — java DAP wiring with
hot-code-replace, called in `on_attach`.

### 4. `ls /usr/lib/jvm/default-java` succeeds

```
$ ls /usr/lib/jvm/default-java
/usr/lib/jvm/default-java -> java-1.21.0-openjdk-amd64
```

JDK 21 symlink resolves — the `JavaSE-21` runtime path in the config is valid.

## Summary

All 4 acceptance criteria PASS. `after/ftplugin/java.lua` (2.2K) contains the
full jdtls config: mason `bin/jdtls` binary resolution, `vim.fs.root` project
root detection (`.git`/`mvnw`/`pom.xml`/`gradlew`/`settings.gradle`/
`build.gradle` markers), per-project workspace cache under
`stdpath('cache')/jdtls/workspace/<project-name>`, blink capabilities helper,
JDK 21 runtime + maven/gradle/eclipse settings + `LOMBOK_JAR` vmargs hook,
`setup_dap { hotcodereplace = 'auto' }`, and `<leader>oi`/`<leader>ot`/
`<leader>om` organize-imports/test keymaps. jdtls is NOT added to lspconfig or
`vim.lsp.enable` (guardrail respected). Live attach verified in task-11
evidence.