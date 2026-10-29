#!/usr/bin/env bash
# desc: herdr (terminal workspace manager for AI agents) + its plugins
# os: any
# check: command -v herdr >/dev/null && herdr plugin list 2>/dev/null | grep -q 'herdr.auto-title' && herdr plugin list 2>/dev/null | grep -q 'assawalhy.stay-awake' && herdr plugin list 2>/dev/null | grep -q 'numbered.ports'
# prio: p2
set -euo pipefail

command -v herdr >/dev/null || curl -fsSL https://herdr.dev/install.sh | sh

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
