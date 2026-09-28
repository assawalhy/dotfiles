#!/usr/bin/env bash
# desc: pyenv
# os: any
# check: command -v pyenv || [ -d "$HOME/.pyenv" ]
# prio: p2
set -euo pipefail
# on macOS use the packaged brew build; compiling the pyenv shim from source
# takes more work
if [ "$(uname -s)" = Darwin ] && command -v brew >/dev/null 2>&1; then
  brew install pyenv
  exit 0
fi
git clone https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
cd "$HOME/.pyenv" && src/configure && make -C src
