# Task 7 Evidence — nvim-config-cleanup-and-java

**Task:** Add maven and gradle to setup/packages.list
**Date:** 2026-08-16
**Commit:** `5c4bf98 test: add nvim headless smoke test`
**Status:** **PASS** (2/2 criteria)

## Acceptance criteria

### 1. `grep -n '^maven\|^gradle' setup/packages.list` shows both with p2

```
$ grep -n '^maven\|^gradle' setup/packages.list
    69: maven p2
    70: gradle p2
```

Both entries present, both tagged `p2` (dev workstation tier), no per-manager
override needed (apt names match on this distro).

### 2. `./setup-os --list 2>/dev/null | grep -iE 'maven|gradle'` shows both

```
$ ./setup-os --list 2>/dev/null | grep -iE 'maven|gradle'
dev        maven                  p2     apt      maven
dev        gradle                 p2     apt      gradle
```

Both resolve through the installer: group `dev`, tier `p2`, manager `apt`,
package name `maven` / `gradle`.

## Summary

All 2 acceptance criteria PASS. `maven p2` and `gradle p2` are in
`setup/packages.list` (lines 69-70) and both resolve via `./setup-os --list`
as apt packages in the p2 tier. No changes to `setup-os` itself (guardrail
respected). JDK entries were deliberately not added — JDK 21 is already
installed at `/usr/lib/jvm/default-java` (see task-10 evidence).