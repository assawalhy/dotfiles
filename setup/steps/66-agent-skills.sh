#!/usr/bin/env bash
# desc: agent skills & plugins (interactive: run setup/agent-skills.sh)
# os: any
# prio: p2
set -euo pipefail

cat <<'EOF'
Agent skills and plugins are managed from the catalog:

  bash setup/agent-skills.sh            # pick from the catalog
  bash setup/agent-skills.sh --all      # install everything, no prompt
  bash setup/agent-skills.sh --list     # catalog with installed markers
  bash setup/agent-skills.sh --context  # how committed context files are wired

Catalog: setup/agent-skills.list
Skills install into ~/.agents/skills/ (harness-agnostic) or via each harness's
own CLI (pi install, claude plugin, codex plugin). Multi-harness tools
(context7, plannotator, warp, typescript-lsp) install into every harness
present via setup/agent-tools.sh. The awesome-agent plugin installs its own
commands/agents/skills into every harness; context files
(common/.agents/AGENTS.md, common/.claude/CLAUDE.md) are symlinked by
link-files --fix, not by this script.
EOF