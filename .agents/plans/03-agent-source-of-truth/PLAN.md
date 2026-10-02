# PLAN — unified agent source of truth

## Goal

Make the dotfiles repo the single, transferable source of truth for agent
setup. Two kinds of artifacts, two rules:

- **Installable artifacts** (plugins, MCPs, skills, packages) → recorded in the
  catalog; the script installs them fresh on any machine. No config files copied.
- **Authored context files** (AGENTS.md, CLAUDE.md) → committed in the repo;
  nothing can regenerate them, so the repo is the source.

The last commit (d43b108) introduced the catalog + installer + a 2-line
`common/.agents/AGENTS.md` stub. The model is right but broken in practice:
`--list` crashes, the real context was never committed, and two systems fight
over `~/.agents/AGENTS.md`.

## Reality found on this machine

| Artifact | Kind | Action |
|---|---|---|
| `~/.agents/AGENTS.md` (143 lines: writing style, git rules, planning, toolchain, test etiquette) | authored context | commit as `common/.agents/AGENTS.md` (replace 2-line stub) |
| `~/.claude/CLAUDE.md` ("you are the awesome-agent", imports `~/.agents/AGENTS.md`) | authored context | commit as `common/.claude/CLAUDE.md` |
| `~/.config/opencode/opencode.jsonc` | config file, contents all installable | NOT copied — record `opencode-plugin\|plannotator` + `opencode-mcp\|context7` in catalog; `default_agent` is already set by the awesome-agent plugin itself |
| `~/.agents/skills/*` (13 skills) | installable (or vendored) | catalog: add `agents-skill\|teach`; commit `setup/skills/graphify` (no public repo URL → vendored) |
| claude plugins: context7, warp, typescript-lsp, plannotator | installable | catalog: replace fake medusa/slack entries with the real installed 4 |
| `~/.codex/config.toml` (hooks=true), `~/.claude/settings.json` (38KB Orca/autoMode state) | machine state, generated | leave out of the repo entirely |
| awesome-agent plugin | separate repo | catalog entry `plugin\|awesome-agent` clones + runs its install.sh — unchanged, do not mirror |
| `setup/agent-skills.sh --list` | repo | crash (set -e + non-zero `installed_path`) — fix |
| `wire_context` in agent-skills.sh | repo | duplicate of link-files' job — remove |

## Approach

1. **Promote authored context into the repo (link-files owns these):**
   - `common/.agents/AGENTS.md` ← real 143-line content (verbatim; keep the
     Taager-specific build/test etiquette — it is today's usable context)
   - `common/.claude/CLAUDE.md` ← real content
2. **Fix `agent-skills.sh`:** `installed_path` must exit 0 when an item is not
   installed, so `--list`/`--dry-run`/interactive never abort (exit-1 bug).
3. **Remove `wire_context`** from agent-skills.sh — context files are dotfiles
   managed by `link-files --fix`. `--context` becomes "run link-files".
4. **Reconcile the catalog to reality (source of truth for installables):**
   - claude-plugin entries → the 4 actually-enabled plugins (context7, warp,
     typescript-lsp, plannotator) with their real marketplace install commands
   - new category `opencode-plugin`: `opencode plugin @plannotator/opencode`
   - new category `opencode-mcp`: context7 via a deterministic config merge / CLI
   - add `agents-skill|teach` (present in this machine's `.skill-lock.json`)
   - add `vendored-skill|graphify` + commit `setup/skills/graphify/`
   - keep `plugin|awesome-agent`, pi-package entries, codex optional entries
   - add comment: `~/.agents/.skill-lock.json` is Claude's native skill-sync
     state; the catalog is the repo-owned install path
5. **Update step 66 + AGENTS.md** to the two-rule ownership map.
6. **Verify:** link-files `--fix` + audit; fresh-machine dry run; full bats suite.

## Decisions (with rationale)

- **Installable → record; authored → commit.** Rejected: copying whole config
  files (opencode.jsonc, settings.json) — they are machine state and drift;
  rejected: generating authored context from stubs — the real rules are
  irreplaceable.
- **link-files owns committed context; agent-skills owns installs.**
  Rejected: `wire_context` writing `~/.agents/AGENTS.md` — two writers for one
  path (audit already flags `[conflict]`).
- **Catalog mirrors the real installed set** (claude plugins = the 4 enabled,
  not medusa/slack). Rejected: keeping aspirational entries — a fresh machine
  should reproduce what actually works here. Optional entries stay optional.
- **opencode config is regenerated, not copied**: `default_agent` already set
  by the plugin; plugin + MCP from catalog entries. Rejected: committing
  `common/.config/opencode/opencode.jsonc`.
- **awesome-agent stays a separate repo**, referenced by catalog (rejected:
  mirroring into `common/` — plugin writes fight the links).
- **graphify vendored** under `setup/skills/` (no public clone URL; the
  `vendored-skill` catalog category exists for exactly this).

## Milestones

1. Promote context files into `common/` (AGENTS.md real content + CLAUDE.md).
2. Fix `agent-skills.sh` crash + remove `wire_context`.
3. Reconcile catalog: claude plugins, opencode-plugin/-mcp categories, teach,
   graphify vendored; commit `setup/skills/graphify`.
4. Update docs (step 66, AGENTS.md ownership map).
5. link-files `--fix` (backups) + audit green.
6. Fresh-machine dry run in scratch HOME + full bats suite.

## Follow-up (2026-10-03) — `~/.claude` audit boundary

`~/.claude` is a *linked dir* (because `CLAUDE.md` is linked there), so
`--audit`'s refresh scan treats every real file under it as an `[unlinked]`
capture candidate. Plugin/tool installs and Claude Code's runtime state keep
landing there: agents, commands, skills (awesome-agent plugin + agent-tools),
backups, cache, sessions, telemetry, settings.json.

Decision: scope the whole directory out of capture with a **root-anchored
`/.claude/` entry in `.gitignore`** (gitignore is already a documented
capture filter in refresh_scan, covered by tests). Only
`common/.claude/CLAUDE.md` is committed and linked; everything home-only under
`~/.claude` becomes invisible to `--refresh`/`--audit` without enumerating
runtime dirs.

- Root-anchored (`/.claude/`, not `.claude/`): `common/.claude/` stays visible
  to git, so new authored context files are never silently gitignored
  (verified in a scratch repo).
- Rejected: enumerating deny entries in link-ignore.txt — maintenance churn as
  Claude Code grows new runtime dirs.
- Rejected: `!` re-include support in link-ignore.txt — core-matcher change,
  and a forgotten re-include silently unlinks committed files (the audit
  cannot see ignored repo files).
- The uncommitted `link-ignore.txt` `.claude/plugins` line is superseded by
  the `.gitignore` rule and gets reverted (never landed in a commit). The
  committed herdr-hook entry stays (ownership note, harmless).

Also: `common/.config/nvim/lua/config/lsp_sources.lua` (added in c92aefa,
`require`d by `java.lua`) is committed but not linked in `$HOME` — `--fix`
links it.

Milestone 7:
- `.gitignore`: `/.claude/` + comment; revert the `.claude/plugins` link-ignore line.
- `link-files --fix` → `--audit` clean → bats suite green → commit.