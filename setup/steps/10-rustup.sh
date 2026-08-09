#!/usr/bin/env bash
# desc: rust (rustup)
# os: any
# check: command -v cargo
set -euo pipefail
# -y: the bare installer blocks on an interactive prompt
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
