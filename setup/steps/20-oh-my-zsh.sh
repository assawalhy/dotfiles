#!/usr/bin/env bash
# desc: oh-my-zsh
# os: any
# check: [ -d "$HOME/.oh-my-zsh" ]
# prio: p1
set -euo pipefail
# --unattended: without it the installer runs chsh and starts an interactive
# shell in the middle of the run
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
