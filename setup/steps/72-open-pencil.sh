#!/usr/bin/env bash
# desc: open-pencil (design editor for .fig/.pen files) as the official self-updating AppImage
# os: any
# check: test -x "$HOME/Applications/open-pencil.AppImage"
# prio: p3
set -euo pipefail

# OpenPencil desktop, from the official GitHub release.
#
# Installed as a plain AppImage under ~/Applications on purpose: the app's own
# updater installs the AppImage by rewriting the file it was launched from, which
# a read-only /nix/store path forbids. The deb build updates through pkexec and a
# package manager instead, which NixOS has neither of. See
# .agents/plans/21-self-updating-apps and .agents/plans/44-open-pencil.
#
# On NixOS the AppImage runs through binfmt to appimage-run, which exports
# APPIMAGE, and that is what the updater reads to find the file to replace.

if [ "$(uname -s)" = Darwin ]; then
  echo "open-pencil: install the dmg from https://openpencil.dev/download" >&2
  exit 1
fi

app="$HOME/Applications/open-pencil.AppImage"
icon="$HOME/.local/share/icons/hicolor/128x128/apps/open-pencil.png"

mkdir -p "$HOME/Applications" "$(dirname "$icon")"

if [ -x "$app" ]; then
  echo "open-pencil AppImage already present (it self-updates); left as is"
else
  tag="$(curl -fsSL https://api.github.com/repos/open-pencil/open-pencil/releases/latest | jq -r .tag_name)"
  ver="${tag#v}"
  if [ -z "$ver" ] || [ "$ver" = "$tag" ]; then
    echo "open-pencil: could not resolve the release tag" >&2
    exit 1
  fi
  echo "downloading open-pencil $ver"
  curl -fL --progress-bar -o "$app.tmp" \
    "https://github.com/open-pencil/open-pencil/releases/download/$tag/OpenPencil_${ver}_amd64.AppImage"
  chmod +x "$app.tmp"
  mv "$app.tmp" "$app"
fi

# Icon comes from the AppImage itself, so nothing binary needs committing.
#
# `appimage-run -x` is used rather than `<appimage> --appimage-extract`: the
# kernel sends every AppImage exec through binfmt, and the live interpreter here
# is stock appimage-run-bwrap, which forwards --appimage-extract to AppRun and
# therefore starts the app instead of extracting. nix/appimage-binfmt.sh (epic
# 42) adds the extract branch, but it is not switched in yet, and this step must
# work either way. `-x` is an explicit call, so binfmt never sees it.
if [ ! -e "$icon" ]; then
  runner="$(command -v appimage-run || true)"
  [ -n "$runner" ] || runner="$HOME/.nix-profile/bin/appimage-run"
  if [ -x "$runner" ]; then
    tmp="$(mktemp -d)"
    "$runner" -x "$tmp" "$app" >/dev/null 2>&1 || true
    png="$(find "$tmp" -name 'OpenPencil.png' | head -1)"
    if [ -n "$png" ]; then
      cp "$png" "$icon"
    else
      echo "open-pencil: no icon in the AppImage; the app grid entry keeps a blank icon" >&2
    fi
    rm -rf "$tmp"
  else
    echo "open-pencil: appimage-run is not on PATH; the app grid entry keeps a blank icon" >&2
  fi
fi

echo "open-pencil installed at $app"
