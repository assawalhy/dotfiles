#!/usr/bin/env bash
# desc: rust (rustup)
# os: any
# check: command -v cargo
# prio: p1
set -euo pipefail
# -y: without it the installer waits for input at an interactive prompt
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
