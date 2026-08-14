#!/usr/bin/env bash
# desc: homebrew
# os: macos
# check: command -v brew
# prio: p1
set -euo pipefail
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
