#!/usr/bin/env bash
# desc: tmux plugin manager
# os: any
# check: [ -d "$HOME/.tmux/plugins/tpm" ]
set -euo pipefail
git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
