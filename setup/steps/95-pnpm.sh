#!/usr/bin/env bash
# desc: pnpm
# os: any
# check: command -v pnpm
# prio: p2
set -euo pipefail
# the old unpkg.com/@pnpm/self-installer endpoint has been dead for years
curl -fsSL https://get.pnpm.io/install.sh | sh -
