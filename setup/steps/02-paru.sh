#!/usr/bin/env bash
# desc: paru (AUR helper)
# os: linux
# check: command -v paru || command -v yay || ! command -v pacman
# prio: p1
set -euo pipefail
command -v pacman >/dev/null || { echo "not an Arch system, skipping"; exit 0; }
sudo pacman -S --needed --noconfirm base-devel git
tmp="$(mktemp -d)"
git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
cd "$tmp/paru-bin"
makepkg -si --noconfirm
rm -rf "$tmp"
