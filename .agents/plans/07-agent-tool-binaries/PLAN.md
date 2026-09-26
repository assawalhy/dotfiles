# Plan — agent-tool binaries (plannotator, graphify) + drop warp

## Goal
`setup/agent-tools.sh` installs each tool's **full upstream utility set**, not just
harness plugins/configs: the `plannotator` CLI (plus its sem sidecar and
agent-terminal runtime) and the `graphify` CLI (plus its per-harness skill).
Remove `warp` entirely.

## Why (findings from research)
- `plannotator_bin_install` already runs the official installer, but pipes its
  stderr to `/dev/null` and never checks the result: a slow or failed ~154 MB
  download is swallowed while the plugin steps still report success → "binary
  not installed".
- The official installer is interactive (wizard on `/dev/tty`, 30 s prompt
  timeouts) → non-deterministic when driven from `setup-os`/`agent-skills.sh`.
- A scratch-`$HOME` run confirms the official installer *does* install the
  binary + `sem` sidecar + hooks/skills (the agent-terminal runtime is
  best-effort; its npm step can fail harmlessly).
- `plannotator_status` / `graphify_status` use `command -v` only;
  `~/.local/bin/<bin>` is the PATH-robust check matching the marker design.
- `warp` is not installed on this machine (no claude/codex plugin) → removal is
  code/catalog/docs only, no uninstall.

## Decisions
- plannotator binary: run `install.sh | bash -s -- --non-interactive`, keep its
  output (log + tail on failure), verify `~/.local/bin/plannotator`, and fail the
  catalog item loudly when absent. *(Rejected: `--minimal` — drops sem/runtime;
  rejected: fetch the release asset directly — reimplements upstream and still
  needs sem/runtime wiring.)*
- Keep the separate opencode/claude/pi plugin/extension installs: upstream docs
  require them independently of the binary.
- graphify: keep `uv tool install graphifyy[sql]` + `graphify install --platform
  <p>`; surface failures and verify the binary and skill paths. *(Rejected:
  graphify extras like `[video]`/`[office]` — per-capability opt-ins, not the
  upstream "full install".)*
- `status` prefers the explicit `~/.local/bin` path, then `command -v`.
- Remove warp from code, catalog, and docs (not installed anywhere).
- Out of scope: plannotator's VS Code/Obsidian/Bear integrations — not installed
  by the official installer.

## Milestones
1. plannotator: non-interactive, verified, failure-propagating binary install.
2. graphify: verified binary + platform install, failures visible.
3. warp removed from every reference.
4. Scratch-`$HOME` live verification + full suite.

## Risks
- The plannotator step downloads 154 MB (~3 min): slow, but documented, not hidden.
- The official installer mutates many harness homes; the binary-exists guard makes
  it run at most once per machine.
- `graphify install --platform <p>` acceptance per harness is unverified → covered
  by the live-verify step.
