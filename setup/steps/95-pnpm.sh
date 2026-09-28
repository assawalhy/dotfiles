#!/usr/bin/env bash
# desc: pnpm
# os: any
# check: command -v pnpm
# prio: p2
set -euo pipefail
# the former unpkg.com/@pnpm/self-installer endpoint no longer serves the
# installer
curl -fsSL https://get.pnpm.io/install.sh | sh -
