#!/usr/bin/env bash
# desc: cht.sh
# os: any
# check: command -v cht.sh
set -euo pipefail
# install to ~/.local/bin (already on PATH via .bash_profile) -- no sudo needed
mkdir -p "$HOME/.local/bin"
curl -fsSL https://cht.sh/:cht.sh -o "$HOME/.local/bin/cht.sh"
chmod +x "$HOME/.local/bin/cht.sh"
