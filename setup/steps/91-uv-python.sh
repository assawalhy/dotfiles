#!/usr/bin/env bash
# desc: uv python (python, python3)
# os: any
# check: [ -e "$HOME/.local/bin/python" ]
# prio: p2
# requires: uv
set -euo pipefail

# python3 must resolve for envfs (/usr/bin/python3) and the nvim/ranger
# shebangs; pip is deliberately absent -- use `uv pip` or `python3 -m pip`.
uv python install 3 --default

echo "✓ uv python ready"
command -v python3 >/dev/null 2>&1 && python3 --version
