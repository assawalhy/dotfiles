#!/usr/bin/env bash
# desc: herdr workspace-manager plugin (worktree layouts) + remove-gone CLI
# os: any
# check: herdr plugin list 2>/dev/null | grep -q herdr-plugin-workspace-manager && command -v herdr-workspace-manager >/dev/null
# prio: p2
set -euo pipefail
herdr plugin install razajamil/herdr-plugin-workspace-manager --yes
curl -fsSL https://raw.githubusercontent.com/razajamil/herdr-plugin-workspace-manager/main/install.sh | bash
