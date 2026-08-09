#!/usr/bin/env bash
# desc: wallpapers (dwt1)
# os: any
# check: [ -d "${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers" ]
set -euo pipefail
dest="${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers"
mkdir -p "$(dirname "$dest")"
git clone https://gitlab.com/dwt1/wallpapers "$dest"
