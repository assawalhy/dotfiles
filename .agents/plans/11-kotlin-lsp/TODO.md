# TODO — Official Kotlin LSP (#18)

- [x] epic dir + PLAN/TODO, comment plan on #18 (plan decisions live in the issue body)
- [x] `setup/steps/67-kotlin-lsp.sh`: CDN tar.gz, sha256, `current` symlink (bash -n ok)
- [x] run the step; `~/.local/share/kotlin-lsp/current/bin/intellij-server --stdio` reachable
- [x] `config/java.lua`: kotlin_lsp primary, kls fallback + jvm.target settings fix (loadfile ok)
- [x] `config/memory.lua`: watch `kotlin_lsp`, reaper needle `kotlin-lsp/` (loadfile ok)
- [x] `link-files --fix --yes`: 69 links correct, nothing to do
- [x] primary probe (real config): `kotlin_lsp` attaches, 0 diagnostics both files, clean `ExitPre`
- [x] fallback probe (binary hidden): kls attaches, 1 diagnostic (jvm.target fix live)
- [x] memory guard: per-server floors — kotlin_lsp tripped the 1.5 GiB floor mid-session; it gets 0.75 GiB, jdtls/kls keep 1.5 GiB
- [x] reaper needle validated: server cmdline is `kotlin-lsp/current/bin/intellij-server`
- [x] `bats tests/link-files.bats`: 99 ok, 0 not ok
- [ ] commits (`setup:`, `nvim:`) + push + PR
