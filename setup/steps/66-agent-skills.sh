#!/usr/bin/env bash
# desc: agent skills & plugins (interactive: run setup/agent-skills.sh)
# os: any
# prio: p2
set -euo pipefail

cat <<'EOF'
Agent skills, plugins and shared context files are managed interactively:

  bash setup/agent-skills.sh            # pick from the catalog, then wire context
  bash setup/agent-skills.sh --all      # install everything, no prompt
  bash setup/agent-skills.sh --list     # catalog with installed markers
  bash setup/agent-skills.sh --context  # only (re)wire shared context .md files

Catalog: setup/agent-skills.list
Skills install into ~/.agents/skills/ (harness-agnostic) or via each harness's
own CLI (pi install, claude plugin, codex plugin). The awesome-agent plugin
installs its own commands/agents/skills into every harness; only
~/.agents/AGENTS.md is symlinked from common/.
EOF