# Task 11 — Java QA: sample Maven project + headless attach verification

Date: 2026-08-16
Plan: `.omo/plans/nvim-config-cleanup-and-java.md` T11
Status: **PASS** (with one documented plan-assertion drift, see below)

## 1. Sample project created (OUTSIDE repo, not committed)

`/tmp/opencode/java-qa-sample/`:

```
pom.xml
src/main/java/com/example/Hello.java
src/test/java/com/example/HelloTest.java
```

- `pom.xml`: maven-compiler-plugin `<release>21</release>`, junit-jupiter 5.10.2 test dependency, surefire 3.2.5.
- `Hello.java`: `com.example.Hello` with a `greet(String)` method + a `// TODO: localize the greeting` comment.
- `HelloTest.java`: one passing test (`greetReturnsExpectedMessage`).

## 2. Headless attach verification

### 2a. Exact command run (as specified in the plan/task)

```
XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless --cmd 'let g:codeium_enabled = v:false' -c 'edit /tmp/opencode/java-qa-sample/src/main/java/com/example/Hello.java' -c 'sleep 60' -c 'lua local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients()); assert(vim.tbl_contains(names, "jdtls"), "jdtls not attached: " .. vim.inspect(names))' -c 'lua local dap = require("dap"); assert(dap.configurations.java and #dap.configurations.java > 0, "no java dap configs")' -c 'qa!'
```

### 2b. Full output

```
Init...
0% Starting Java Language Server
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 11KB/32KB (36%) https://repo.mav
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 67KB/116KB (57%) https://repo.ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 36KB/319KB (11%) https://repo.ma
27% Starting Java Language Server - 56KB/56KB (100%) https://repo.ma
27% Starting Java Language Server - 22KB/90KB (24%) https://repo.mav
27% Starting Java Language Server - 280KB/319KB (87%) https://repo.m
27% Starting Java Language Server - 88KB/326KB (26%) https://repo.ma
27% Starting Java Language Server - 73KB/187KB (39%) https://repo.ma
27% Starting Java Language Server - 208KB/326KB (63%) https://repo.m
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - https://repo.maven.apache.org/ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 57KB/103KB (55%) https://repo.ma
27% Starting Java Language Server - 0% https://repo.maven.apache.org
27% Starting Java Language Server - 49KB/238KB (20%) https://repo.ma
27% Starting Java Language Server - 112KB/200KB (55%) https://repo.m
27% Starting Java Language Server - 200KB/572KB (34%) https://repo.m
27% Starting Java Language Server - 312KB/572KB (54%) https://repo.m
27% Starting Java Language Server - 424KB/572KB (74%) https://repo.m
27% Starting Java Language Server - 536KB/572KB (93%) https://repo.m
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 0% https://repo.maven.apache.org
59% Starting Java Language Server - 24KB/53KB (44%) https://repo.mav
59% Starting Java Language Server - 104KB/263KB (39%) https://repo.m
59% Starting Java Language Server - 232KB/263KB (88%) https://repo.m
59% Starting Java Language Server - 175KB/573KB (30%) https://repo.m
59% Starting Java Language Server - 319KB/573KB (55%) https://repo.m
59% Starting Java Language Server - 479KB/573KB (83%) https://repo.m
70% Starting Java Language Server - Refreshing '/java-qa-sample/src/
OK
100% Starting Java Language Server - Refreshing '/java-qa-sample/src
1000% Starting Java Language Server - Refreshing '/java-qa-sample/sr
1005% Starting Java Language Server - Refreshing '/java-qa-sample/sr
1010% Starting Java Language Server - Refreshing '/java-qa-sample/sr
1100% Starting Java Language Server - Refreshing '/java-qa-sample/sr
1100% Starting Java Language Server - Refreshing '/java-qa-sample/sr
Ready
1100% Starting Java Language Server - Refreshing '/java-qa-sample/sr
ServiceReady
Error in command line:
E5108: Lua: [string ":lua"]:1: no java dap configs
stack traceback:
	[C]: in function 'assert'
	[string ":lua"]:1: in main chunk
```

**Attached-client assertion PASSED** — jdtls reached `ServiceReady` and the
`vim.tbl_contains(names, "jdtls")` assertion did NOT fire (no "jdtls not
attached" error). The only failure was the second assertion: `no java dap
configs` (`dap.configurations.java` was empty/nil).

> Note: the process still printed `EXIT_CODE=0` because `-c 'qa!'` is the last
> command and force-quits regardless of the earlier Lua assert error. The
> assertion error is visible in the output above.

## 3. Root cause of the DAP assertion failure — nvim-jdtls API drift (NOT a config bug)

The plan's T11 assertion `dap.configurations.java and #dap.configurations.java > 0`
is **stale for the installed nvim-jdtls version**. In the current
`nvim-jdtls/lua/jdtls/dap.lua`, `setup_dap(opts)` (line 709) does NOT populate
`dap.configurations.java`. It sets:

- `dap.adapters.java = start_debug_adapter` (line ~738)
- `dap.providers.configs["jdtls"]` = a dynamic provider that fetches main-class
  configs from the jdtls server on demand (line 741-757)

`dap.configurations.java` is only written by the separate, async, opt-in
`setup_dap_main_class_configs()` (line 668-695), which T10 does not call (and
the plan's T10 spec does not include it — `setup_dap` is the README-standard
call).

### Diagnostic confirming the DAP wiring IS present (setup_dap ran)

```
CLIENTS={ "jdtls" }
ADAPTER_JAVA=true
PROVIDER_JDTLS=true
CONFIGS_JAVA=nil
```

`dap.adapters.java` and `dap.providers.configs["jdtls"]` are both set → the
java DAP wiring from T10's `jdtls.setup_dap({ hotcodereplace = 'auto' })` is
working correctly. The plan assertion simply checked an output this nvim-jdtls
version no longer produces via `setup_dap`.

## 4. Corrected verification (asserts what setup_dap actually produces) — PASS, exit 0

Command:

```
XDG_CONFIG_HOME=/home/ms/myp/dotfiles/common/.config nvim --headless --cmd 'let g:codeium_enabled = v:false' -c 'edit /tmp/opencode/java-qa-sample/src/main/java/com/example/Hello.java' -c 'sleep 60' -c 'lua local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients()); assert(vim.tbl_contains(names, "jdtls"), "jdtls not attached: " .. vim.inspect(names)); print("PASS: jdtls attached")' -c 'lua local dap = require("dap"); assert(dap.adapters.java ~= nil, "no java dap adapter"); assert(dap.providers and dap.providers.configs and dap.providers.configs["jdtls"] ~= nil, "no jdtls dap provider"); print("PASS: java dap adapter + jdtls provider present (setup_dap ran)")' -c 'qa!'
```

Output:

```
Init...
0% Starting Java Language Server
10% Starting Java Language Server
OK
100% Starting Java Language Server - Opening 'java-qa-sample'.
Ready
100% Starting Java Language Server - Opening 'java-qa-sample'.
ServiceReady
PASS: jdtls attached
PASS: java dap adapter + jdtls provider present (setup_dap ran)
EXIT_CODE=0
```

Both assertions pass, exit 0.

## 5. Mason packages

```
$ ls ~/.local/share/nvim/mason/packages | grep -E 'jdtls|java'
java-debug-adapter
java-test
jdtls
```

All three java packages installed (T8 + T3). jdtls jar bundles present:
`java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-0.53.2.jar`
and `java-test/extension/server/*.jar` (incl. junit-platform-launcher etc.).

## 6. Verdict

- Sample Maven project created at `/tmp/opencode/java-qa-sample/` (pom.xml,
  Hello.java, HelloTest.java). Not committed (lives in /tmp/opencode).
- Headless attach: **jdtls attaches cleanly** (`ServiceReady`, attached-client
  assertion passes). Java DAP wiring present (`dap.adapters.java` +
  `dap.providers.configs["jdtls"]`).
- Plan's `dap.configurations.java` assertion is stale for the installed
  nvim-jdtls version; corrected assertion (what `setup_dap` actually produces)
  passes with exit 0. No config change needed — T10's `setup_dap` call is the
  correct, README-standard wiring.
- Evidence written to `.omo/evidence/task-11-nvim-config-cleanup-and-java.md`.
