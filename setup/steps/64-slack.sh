#!/usr/bin/env bash
# desc: Slack (Flatpak, updates without a rebuild)
# os: linux
# check: flatpak info --user com.slack.Slack >/dev/null 2>&1
# prio: p2
# requires: flatpak
set -euo pipefail

# Flathub is the only Slack channel that updates without a rebuild: Slack's own
# Linux updater is an apt repo plus /etc/cron.daily/slack. The daily
# flatpak-update user timer in nix/configuration.nix keeps it current; see
# .agents/plans/49-gui-apps (D2).
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive -y flathub com.slack.Slack
