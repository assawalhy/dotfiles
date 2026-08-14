#!/usr/bin/env bash
# desc: xcode command line tools
# os: macos
# check: xcode-select -p
# prio: p1
set -euo pipefail
xcode-select --install
