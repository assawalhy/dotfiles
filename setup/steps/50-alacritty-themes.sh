#!/usr/bin/env bash
# desc: alacritty colorschemes
# os: any
# check: [ -d "$HOME/.eendroroy-colorschemes" ]
set -euo pipefail
dest="$HOME/.eendroroy-colorschemes"
[ -d "$dest" ] || git clone https://github.com/eendroroy/alacritty-theme.git "$dest"
mkdir -p "$HOME/.config/alacritty"
ln -sfn "$dest/themes" "$HOME/.config/alacritty/colors"
