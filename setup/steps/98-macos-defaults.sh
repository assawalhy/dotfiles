#!/usr/bin/env bash
# desc: macOS system defaults (key repeat, Finder)
# os: macos
# prio: p3
set -euo pipefail

# The one that actually matters: without it, holding j/k in nvim opens the
# accent picker instead of repeating the key.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true

mkdir -p "$HOME/Pictures/screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/screenshots"

killall Finder || true
echo "Some changes need a logout to take effect."
