# TODO — agent-tools status must not be blocked by a pi that can't take packages

- [x] `setup/agent-tools.sh`: add `pi_supports_packages()` — true when
      `pi --help` advertises `install` (upstream pi), false for the Go port
- [x] `plannotator_pi_install`: gate on the probe; when unsupported print
      `- pi: no package support, skipped` instead of a silent `2>/dev/null` fail
- [x] `plannotator_pi_status`: gate on the probe so an incapable pi is not a
      missing leg
- [x] `context7_pi_install` / `context7_pi_status`: same gate
- [x] `plannotator_status`: rename the `klaus` accumulator to `ok`
- [x] remove the unused `harness_status_print` helper
- [x] status path: per-harness `ok` / `missing` diagnostics on stderr (stdout
      contract unchanged — the catalog reads stdout with `2>/dev/null`)
- [x] `setup/agent-skills.list`: note the pi requirement on the
      `pi-package|tmustier-pi-extensions` entry (drop it instead if D4 flips)
- [x] Verify: `bash -n setup/agent-tools.sh`; `status plannotator` prints
      `/home/assawalhy/.agents/tools/plannotator`; `install plannotator`
      reports the pi skip; stderr shows the per-harness lines;
      `bats tests/link-files.bats` still 99 ok / 0 not ok

## Verification log

- `bash -n setup/agent-tools.sh` clean
- `status plannotator` → stderr `binary ok / opencode ok / claude ok /
  pi skipped`, stdout `/home/assawalhy/.agents/tools/plannotator`, rc=0
- `install plannotator` → prints `- pi: no package support (no `pi install`),
  plannotator extension skipped`; opencode reports "already configured" and
  claude "already installed", so the run was a no-op as intended
- `~/.config/opencode/opencode.json` untouched by the run: keys
  `default_agent, permissions, mcp, compaction, plugins` intact,
  `plugins: ["@plannotator/opencode@latest"]` unchanged
- stdout-only sweep (what the catalog sees): plannotator, zvec-grep,
  playwright-cli print markers; context7/typescript-lsp/graphify stay empty —
  context7 for its own two reasons, not as residue of this fix
- `status context7` stderr now names them: `opencode missing mcp`,
  `pi skipped no package support`
- `bats tests/link-files.bats` 99 ok / 0 not ok; `tests/select.bats` 5 ok
- catalog `--list`: item 14 (plannotator) flips `[ ]` → `[x]` with no install