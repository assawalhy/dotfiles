#!/usr/bin/env bash
# desc: oh-my-zsh
# os: any
# check: [ -d "$HOME/.oh-my-zsh" ]
set -euo pipefail
# --unattended: otherwise it runs chsh and execs a subshell in the middle of the run
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
