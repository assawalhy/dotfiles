#!/usr/bin/env bash
# desc: herdr stay-awake plugin (holds a sleep inhibitor while agents work)
# os: any
# requires: herdr
# check: herdr plugin list 2>/dev/null | grep -q 'assawalhy.stay-awake'
# prio: p2
set -euo pipefail

herdr plugin install assawalhy/herdr-stay-awake --yes

# Seed the settings once. The plugin persists them with writeJsonAtomic
# (temp + rename), which replaces a symlink - so the repo ships the defaults
# through this step and the plugin owns the live file afterwards. Toggle
# settings in the UI (prefix+a) from then on.
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
