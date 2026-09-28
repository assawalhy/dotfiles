# TODO — Java/Kotlin toolchain + CP + nvim LSP (#3)

- [x] comment plan on #3
- [x] `common/.config/mise/config.toml`: java temurin-21 + kotlin
- [x] `linux/.config/shell/os.sh`: `_jdk_home` -> `mise where java`
- [x] `common/.bash_profile`: `rkotlin`/`wkotlin` helpers
- [x] `competitest.lua`: kotlin compile/run, java run
- [x] nvim: memory module (gate + watchdog) using `vim.uv`
- [x] nvim: hardened jdtls (direct java, heap cap, per-project workspace)
- [x] nvim: kotlin_language_server with same gate/heap
- [x] nvim: ExitPre stop + startup orphan reaper
- [x] README: rewrite the Java section
- [x] verify: mise java/kotlin, `_jdk_home`, `rjava`, nvim headless gate/watchdog, bats
- [x] commit + push + PR `Closes #3`
