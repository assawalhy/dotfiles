#!/usr/bin/env bash
# desc: herdr (terminal workspace manager for AI agents) + the Herdr app + its plugins
# os: any
# check: command -v herdr >/dev/null && herdr plugin list 2>/dev/null | grep -q 'herdr.auto-title' && herdr plugin list 2>/dev/null | grep -q 'assawalhy.stay-awake' && herdr plugin list 2>/dev/null | grep -q 'numbered.ports' && [ -x "$HOME/.local/bin/herdr-app" ] && [ ! -L "$HOME/.local/bin/herdr-app" ]
# prio: p2
set -euo pipefail

command -v herdr >/dev/null || curl -fsSL https://herdr.dev/install.sh | sh

# The Herdr app, not the CLI. It updates itself in place, so it stays in
# ~/.local/share/herdr-app and never enters the store (epic 49).
install_app() { curl -fsSL https://releases.herdr.dev/app/install.sh | sh; }

if [ "$(uname -s)" = Darwin ]; then
  [ -d "$HOME/Applications/Herdr.app" ] || install_app
else
  [ -x "$HOME/.local/share/herdr-app/herdr-app" ] || install_app

  # nix-ld has neither libwayland-client (epic 04 D5) nor libvulkan, which the
  # GPUI app dlopens, so the installer's symlink is replaced by a wrapper that
  # adds the paths Nix writes to /etc/herdr-app/nix-ld-extra. Herdr's updater
  # only swaps the binary, so the wrapper survives updates (epic 49 D1).
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/herdr-app.new" <<'SH'
#!/bin/sh
# Written by setup/steps/63-herdr.sh. Herdr's installer normally makes this
# path a symlink to ~/.local/share/herdr-app/herdr-app; this wrapper adds the
# Wayland client and Vulkan loader that nix-ld leaves out, then execs that same
# binary. Re-running releases.herdr.dev/app/install.sh resets this file.
set -eu
extra=
if [ -r /etc/herdr-app/nix-ld-extra ]; then
  extra=$(cat /etc/herdr-app/nix-ld-extra)
fi
NIX_LD_LIBRARY_PATH="${NIX_LD_LIBRARY_PATH:-/run/current-system/sw/share/nix-ld/lib}$extra"
export NIX_LD_LIBRARY_PATH
exec "$HOME/.local/share/herdr-app/herdr-app" "$@"
SH
  chmod +x "$HOME/.local/bin/herdr-app.new"
  mv "$HOME/.local/bin/herdr-app.new" "$HOME/.local/bin/herdr-app"
fi

installed() { herdr plugin list 2>/dev/null | grep -q "$1"; }

# auto-title builds from source, so it needs a Go toolchain (step 05-golang.sh or
# the setup-os [go] group). Without Go the step still installs the other two
# plugins and keeps reporting "not installed", so a later run retries it.
if ! installed herdr.auto-title; then
  if command -v go >/dev/null; then
    herdr plugin install kryptamine/herdr-auto-title --yes
    # Herdr starts plugins only with its server, so a fresh install needs this
    # before titles appear in the running session.
    herdr plugin action invoke herdr.auto-title.restart
  else
    echo "skipping herdr auto-title: it needs Go >= 1.24 on PATH" >&2
  fi
fi

if ! installed assawalhy.stay-awake; then
  herdr plugin install assawalhy/herdr-stay-awake --yes
fi

# Seed the stay-awake settings once. The plugin persists them with
# writeJsonAtomic (temp + rename), which replaces a symlink - so the repo ships
# the defaults through this step and the plugin owns the live file afterwards.
# Toggle settings in the UI (prefix+a) from then on.
cfg_dir="$(herdr plugin config-dir assawalhy.stay-awake 2>/dev/null || true)"
if [ -n "$cfg_dir" ] && [ ! -f "$cfg_dir/config.json" ]; then
  mkdir -p "$cfg_dir"
  cat > "$cfg_dir/config.json" <<'JSON'
{
  "enabled": true,
  "grace_enabled": true,
  "start_grace_seconds": 5,
  "stop_grace_seconds": 30,
  "max_hold_seconds": 43200
}
JSON
fi

if ! installed numbered.ports; then
  command -v jq >/dev/null || { echo "herdr ports needs jq on PATH" >&2; exit 1; }
  herdr plugin install Numbered-com/herdr-ports --yes
fi

# The keybindings and the sidebar rows live in the linked config.toml, which a
# running server only picks up on reload.
herdr server reload-config >/dev/null 2>&1 || true
