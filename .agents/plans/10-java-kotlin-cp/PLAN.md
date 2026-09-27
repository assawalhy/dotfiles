# PLAN — Java/Kotlin toolchain + CP + nvim LSP (#3)

## Goal
Working Java and Kotlin toolchains (mise-managed), competitive-programming
support, and a nvim Java/Kotlin LSP that cannot grow without bound and dies
with nvim.

## Stack (as delivered)
The planned chain merged while this epic was in work — but #15 landed on the
already-merged `fix/12` base, so `numhl` never reached master. It is
re-opened as #16 (base master); this epic is #17 (base master, `Closes #3`).

```
master
  ├─ PR #14 (#12 large files, merged)
  ├─ PR #16 (#6 numhl, re-landed on master)
  └─ PR #17 (#3) <- this branch (feat/3-java-kotlin-cp)
```

## Findings
- No JDK anywhere: `java`/`javac` missing, `mvn`/`gradle` unusable,
  `_jdk_home` points at Debian `/usr/lib/jvm/...` paths.
- `rjava`/`wjava` in `common/.bash_profile` call `_jdk_home` -> broken on NixOS.
- jdtls removed in `fabdd18`; `README.md` still documents it (stale).
- RAM/orphan root cause (oh-my-openagent#1479, nvim#29475): the `jdtls` Python
  wrapper is nvim's immediate child and the JVM is a grandchild; nvim kills only
  immediate children on exit and a crash orphans the JVM. No heap cap -> each
  JVM 0.7-1.5 GB, accumulating per workspace.
- `vim.uv.get_free_memory()` / `get_total_memory()` give cross-platform free RAM.
  On Linux `get_free_memory()` is MemFree, not MemAvailable: this box read
  2.7 GiB free against 16.4 GiB available, so a gate on it would block JVM
  servers on a perfectly healthy machine. `memory.free()` reads
  `/proc/meminfo` `MemAvailable` and falls back to `get_free_memory()`
  (macOS, where uv already accounts for reclaimable pages).
- `vim.lsp.enable(name, enable)` takes a **boolean**; a predicate function is
  silently truthy, so the large-file LSP gate shipped in PR #14 was a no-op
  (verified: `lua_ls` attached to a 3.3 MB buffer and both nvim and the server
  pegged a core). The documented per-buffer hook is `root_dir`: no resolved
  root, no activation. #12 now ships `lua/config/lsp_gate.lua` and this epic
  reuses it for the JVM servers.

## Decisions
- JDK: mise `temurin-21`, committed at `common/.config/mise/config.toml`.
  Rejected nixpkgs jdk21 (user chose mise).
- `_jdk_home()` (Linux) delegates to `mise where java`; macOS keeps
  `/usr/libexec/java_home`. Rejected hardcoded store paths.
- Java LSP: hardened jdtls launched as `java` directly (equinox launcher jar,
  `-configuration config_linux`) so nvim's child IS the JVM. Rejected the
  `jdtls` wrapper (grandchild JVM -> orphans).
- Heap cap `-Xmx768m -Xms256m`; per-project workspace
  `stdpath('cache')/jdtls/<project>`.
- Kill on exit: `ExitPre` -> `vim.lsp.stop_client`; startup reaper for
  orphaned jdtls whose workspace is under our cache. The reaper matches
  ppid `1` **or** a `systemd --user` parent: systemd --user is a subreaper
  here, so orphans are adopted by it and never report ppid 1.
- RAM gate: skip attach when available RAM < 2 GiB; watchdog every 20 s stops
  Java/Kotlin clients when available < 1.5 GiB (hysteresis on the gate, so a
  stopped server cannot flap back).
- Kotlin: `kotlinc` via mise, `kotlin_language_server` via mason, same gate.
- CP: competitest kotlin compile/run + java run; `rkotlin`/`wkotlin` mirror
  `rjava`/`wjava`.
- Alternative considered: `jls`/`nvim-jls` (lighter, javac-API, Xmx knobs).
  Rejected for now: multi-module Gradle/Maven is experimental and there is no
  Spring Boot tooling, which the work repos use. Revisit if jdtls stays too heavy.
- Lombok defaults to mason's bundled `lombok.jar`; `LOMBOK_JAR` overrides and
  a set-but-missing path is a hard error, not a silent fallback.
- `unzip` + `nodemon` join `setup/packages.list`: mason unpacks `.zip`
  packages (kotlin-language-server would not install without unzip) and
  nodemon backs the `w*` watch helpers.
- Kotlin `root_dir` falls back to `.git`: the shipped spec only lists build
  files, so a bare `.kt` (the CP case) never resolved a root.
- `wkotlin` passes nodemon the whole pipeline as one `-x` string: split
  argv tokens let nodemon slurp `-d` (its own `--delay`), so kotlinc never
  received `-d <jar>` and `java -jar` kept running the stale jar.

## Milestones
1. mise config + `_jdk_home` + CP helpers.
2. competitest java/kotlin.
3. nvim memory module + jdtls/kotlin LSP.
4. README Java section rewrite.
5. Verify.

## Risks
- jdtls remains a JVM; the cap and watchdog bound it, not remove it.
- Kotlin LSP is a second JVM -> the same gate applies.
- mise install is a network step; versions pinned.
