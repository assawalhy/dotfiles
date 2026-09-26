# TODO — agent-tool binaries (plannotator, graphify) + drop warp

- [x] plannotator: `plannotator_bin_install` runs the official installer with
      `-s -- --non-interactive`, keeps output (fail → tail it), verifies
      `~/.local/bin/plannotator`, returns non-zero when absent
- [x] plannotator: `plannotator_install` propagates the binary failure while
      still running the opencode/claude/pi steps
- [x] plannotator: `plannotator_status` accepts `~/.local/bin/plannotator` or
      `command -v plannotator`
- [x] plannotator: fix the OpenCode step — v2 needs `opencode plugin add <pkg>`;
      bare `opencode plugin <pkg>` only printed help (found during verification)
- [x] dispatch: install branches set `rc=$?` and the script ends with
      `exit "$rc"` (the blanket `exit 0` masked every install failure)
- [x] graphify: `graphify_bin_install` / `graphify_platform_install` stop
      swallowing output, verify `~/.local/bin/graphify`, fail loudly
- [x] graphify: `graphify_status` accepts the explicit binary path; report
      missing skill files per harness
- [x] warp: delete functions, dispatch cases, and usage string from
      `setup/agent-tools.sh`
- [x] warp: delete the `agent-tool|warp` entry from `setup/agent-skills.list`
- [x] warp: drop the mention in `setup/steps/66-agent-skills.sh`
- [x] warp: drop the mention in `AGENTS.md` (Tools: line)
- [x] Verify: scratch-`$HOME` live run of `agent-tools.sh install/status
      plannotator` and `graphify`; `bash -n` all edited scripts; `bats
      tests/link-files.bats` still green

## Verification log
- plannotator scratch-`$HOME` install: `EXIT=0`, 154 MB binary +
  `.plannotator/vendor/sem/v0.8.0/sem` present
- plannotator failure path (unwritable `$HOME`): error + installer tail, `rc=1`
- graphify scratch-`$HOME` install: `EXIT=0`, `~/.local/bin/graphify` +
  `graphify-mcp`, codex skill written
- status: green marker with binary+opencode+claude+pi present; empty otherwise;
  always `rc=0`
- `bats tests/link-files.bats` 99 ok / 0 not ok; known-issues 4 fail as designed
- side effect: `opencode plugin add` ignores `$HOME` and wrote
  `plugins: ["@plannotator/opencode@latest"]` into the real
  `~/.config/opencode/opencode.json` (`default_agent`, `mcp` preserved)
