#!/usr/bin/env bash
# desc: ranger devicons plugin
# os: any
# check: [ -d "$HOME/.config/ranger/plugins/ranger_devicons" ]
set -euo pipefail
mkdir -p "$HOME/.config/ranger/plugins"
git clone https://github.com/alexanderjeurissen/ranger_devicons \
  "$HOME/.config/ranger/plugins/ranger_devicons"
