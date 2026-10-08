#!/usr/bin/env bash
# desc: ranger devicons plugin
# os: any
# check: [ -f "$HOME/.config/ranger/plugins/ranger_devicons/__init__.py" ]
# prio: p2
set -euo pipefail
DIR="$HOME/.config/ranger/plugins/ranger_devicons"
URL=https://github.com/alexanderjeurissen/ranger_devicons

# Gate on loadability, not on the directory existing: a leftover empty dir (from
# the old ranger_devicons gitlink) used to satisfy `-d` and silently skipped the
# clone, leaving ranger with no `devicons` linemode.
if [ -f "$DIR/__init__.py" ]; then
  git -C "$DIR" pull --ff-only
else
  rm -rf "$DIR"
  mkdir -p "$(dirname "$DIR")"
  git clone --depth 1 "$URL" "$DIR"
fi
