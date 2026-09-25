# TODO — unified agent source of truth

- [x] Copy real `~/.agents/AGENTS.md` → `common/.agents/AGENTS.md` (verbatim, secret-checked)
- [x] Copy `~/.claude/CLAUDE.md` → `common/.claude/CLAUDE.md`
- [x] Replace `vendor graphify` with `graphify install` (agent-tool: PyPI graphifyy + `graphify install --platform`); removed `setup/skills/graphify`; pre-authored its CLAUDE.md registration so the linked file stays repo-owned
- [x] Fix `installed_path` in `setup/agent-skills.sh` to always exit 0; verify `--list` prints all catalog items without crashing
- [x] Remove `wire_context` from agent-skills.sh; `--context` prints a link-files hint instead
- [x] Reconcile claude-plugin entries in `setup/agent-skills.list` to the 4 actually-enabled plugins (context7, warp, typescript-lsp, plannotator)
- [x] Fold plannotator/context7/etc. into `setup/agent-tools.sh` (agent-tool category); installers use jq for JSON edits that preserve every other key (never touch awesome-agent's `default_agent`/plugin arrays, never link config files)
- [x] Add `agents-skill|teach` to `setup/agent-skills.list`
- [x] Add catalog comment: `.skill-lock.json` is Claude native skill-sync state, catalog is repo-owned
- [x] Update `setup/steps/66-agent-skills.sh` text (context now via link-files)
- [x] Update `AGENTS.md` "Agent Skills & Shared Context" ownership map
- [x] Run `link-files --fix` (backs up old files) then `link-files --audit` — both context files symlinked; audit green for agent paths
- [x] Live-check `agent-tools.sh install graphify` — installed to opencode/claude/codex/pi/kiro; status marker prints; CLAUDE.md symlink untouched
- [ ] Fresh-machine dry run: scratch HOME, `agent-skills.sh --list` + `--dry-run` + `link-files --audit`
- [ ] Run `bats tests/link-files.bats` (full suite green)
- [ ] Commit with `agents:` scope