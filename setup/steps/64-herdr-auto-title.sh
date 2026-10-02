#!/usr/bin/env bash
# desc: herdr auto-title plugin (names tabs/panes from branch, agent work)
# os: any
# requires: herdr
# check: herdr plugin list 2>/dev/null | grep -q 'herdr.auto-title'
# prio: p2
set -euo pipefail

# Herdr builds the plugin from source, so a Go toolchain is required (the
# setup-os [go] group or step 05-golang.sh provides it).
command -v go >/dev/null || { echo "herdr auto-title needs Go >= 1.24 on PATH" >&2; exit 1; }

herdr plugin install kryptamine/herdr-auto-title --yes
# Herdr starts plugins only with its server, so a fresh install needs this
# before titles appear in the running session.
herdr plugin action invoke herdr.auto-title.restart
