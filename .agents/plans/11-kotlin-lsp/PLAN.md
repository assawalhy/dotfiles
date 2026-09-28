# PLAN — Official Kotlin LSP (#18)

## Goal
Eliminate the false Kotlin diagnostics on Kotlin 2.3 projects by replacing
fwcd/kotlin-language-server (stuck on Kotlin 2.1.0) with JetBrains' official
`Kotlin/kotlin-lsp`, without regressing machines that lack the new install.

## Findings
- kls cannot read kotlin-stdlib 2.3.21 metadata -> `KClass` members
  (`::class.java`) unresolved + metadata error. Upstream latest *and* master
  pin Kotlin 2.1.0; fwcd#457 same class, open. Permanent on kls.
- The `settings.kotlin.compiler.jvm.target` channel via
  workspace/didChangeConfiguration works (verified: 2 -> 1 diagnostics); it
  only fixes the "cannot inline" one — shipped in the kls fallback path.
- kotlin-lsp v263.4702.0 verified in scratch config: 0 diagnostics both demo
  files (t=15..240s), planted error caught, hover/goto `.java` resolve into
  kotlin-stdlib-2.3.21 sources, root via build-files->`.git` fallback,
  peak RSS ~1.1 GiB (fits 2/1.5 GiB gate).
- Not in mason; Linux tar.gz on JetBrains CDN (368 MB, bundled JBR 25);
  brew formula is macOS-only (.sit installers).

## Decisions
- Adopt kotlin-lsp as primary. Rejected: kls-only settings fix (leaves the
  reported `.java` bug), building kls master (still Kotlin 2.1.0),
  downgrading project Kotlin (breaks Spring Boot 4.1 toolchain).
- kls stays as fallback where `intellij-server` is missing (macOS for now),
  carrying the verified jvm.target=21 settings fix.
- Linux-only install step (`# os: linux`); macOS .sit support = follow-up.
- Version-pinned + sha256 (`1e11d2e5...`) in `67-kotlin-lsp.sh`; bumping is
  a deliberate edit. Extract to `~/.local/share/kotlin-lsp/<ver>/` with a
  `current` symlink so the nvim config never changes across upgrades.
- Keep `kotlin_language_server` in mason ensure_installed (the fallback).

## Milestones
1. Issue #18 + epic + branch.
2. `setup/steps/67-kotlin-lsp.sh` + run it.
3. `java.lua` swap/fallback + `memory.lua` watch/reap.
4. Verify: probes against the real config + bats + link-files.
5. Commits + PR (merge only after approval).

## Risks
- kotlin-lsp is Alpha: version pinned; re-verify on every bump.
- First indexing may be slower than the t=15s seen on this small project.
