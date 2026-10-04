#!/usr/bin/env bash
# desc: opencode config files (seed opencode.json + cli.json if absent)
# os: any
# check: [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/cli.json" ] && { [ -f "$HOME/.config/opencode/opencode.jsonc" ] || [ -f "$HOME/.config/opencode/opencode.json" ] || [ -f "$HOME/.config/opencode.jsonc" ] || [ -f "$HOME/.config/opencode.json" ]; }
# prio: p1
#
# A fresh machine has no ~/.config/opencode at all: 61-opencode.sh installs the
# binary and nothing else, so the agent starts with no server config and no CLI
# preferences. This step copies the committed templates into place.
#
# Create-if-missing, then keep topping up (see seed()): the committed template
# is merged *underneath* an existing config, never over it. That keeps the step
# order-independent and idempotent while never undoing a user's or a tool's own
# keys. The JSONs are seeded rather than symlinked on purpose -- link-files
# symlinks the committed app configs, but a symlinked opencode.json does not
# survive its own writers: setup/agent-tools.sh's jq_add_key does
# `mktemp` -> `jq` -> `mv`, and `mv` over a symlink replaces it with a regular
# file. See AGENTS.md, "Restore opencode context files and configs on a fresh
# system".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$(cd "$SCRIPT_DIR/../templates" && pwd)"

# Same precedence as setup/agent-tools.sh:opencode_cfg().
opencode_cfg() {
  for f in "$HOME/.config/opencode/opencode.jsonc" \
           "$HOME/.config/opencode/opencode.json" \
           "$HOME/.config/opencode.jsonc" \
           "$HOME/.config/opencode.json"; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

# Prefer whichever path already exists, so an existing config is never bypassed
# by a lower-precedence sibling. When none exists, default to opencode.json so
# the committed template keeps its extension: never seed a .jsonc path, because
# agent-tools' jq_add_key rewrites through `jq`, which would strip its comments.
opencode_cfg_target() {
  local f
  for f in "$HOME/.config/opencode/opencode.jsonc" \
           "$HOME/.config/opencode/opencode.json" \
           "$HOME/.config/opencode.jsonc" \
           "$HOME/.config/opencode.json"; do
    [ -e "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  printf '%s\n' "$HOME/.config/opencode/opencode.json"
}

# Per the CLI docs, cli.json honours XDG_CONFIG_HOME; opencode.json does not.
cli_cfg() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/cli.json"
}

# Create-if-missing, then keep topping up: an existing config belongs to whoever
# wrote it -- the user, or a tool patching it with jq (context7, plannotator,
# zvec-grep). Clobbering it here would undo those writes on every run, so the
# template is merged *underneath* the file: keys the file already has always
# win, and only keys it lacks are filled in. That also makes this step
# order-independent -- a tool that creates a bare `{}` config first still ends up
# with the committed defaults, instead of silently losing them.
seed() { # <template> <target> <label>
  local tpl="$1" target="$2" label="$3" tmp
  if [ ! -f "$tpl" ]; then
    printf '  - %s: template %s missing, skipped\n' "$label" "$tpl" >&2
    return 0
  fi
  mkdir -p "$(dirname "$target")" 2>/dev/null || true
  if [ ! -e "$target" ]; then
    cp "$tpl" "$target"
    # opencode keeps its own config 0600; match it so a seeded file is not more
    # permissive than the one opencode writes itself.
    chmod 600 "$target" 2>/dev/null || true
    printf '  + %s: seeded from %s\n' "$target" "$tpl"
    return 0
  fi

  # Already present. If every top-level key the template defines is already
  # there, this file is the config we wanted -- leave it byte-for-byte alone.
  # Re-merging would be semantically a no-op but would still rewrite it in jq's
  # formatting and key order, i.e. churn a file nobody asked us to touch.
  command -v jq >/dev/null 2>&1 || {
    printf '  = %s: exists, left unchanged (jq missing, cannot top up)\n' "$target"
    return 0
  }
  if jq -s -e '.[0] as $tpl | .[1] as $tgt | ($tpl | keys) as $k
               | all($k[]; . as $key | $tgt | has($key))' "$tpl" "$target" >/dev/null 2>&1; then
    printf '  = %s: already up to date\n' "$target"
    return 0
  fi

  # Otherwise top it up. `jq -s '.[0] * .[1]'` reads template then target, so
  # target values win and only absent keys are added -- a bare `{}` stub left by
  # another tool still regains the committed defaults instead of losing them.
  tmp="$(mktemp "${TMPDIR:-/tmp}/opencode-config.XXXXXX")" || return 0
  if ! jq -s --indent 2 '.[0] * .[1]' "$tpl" "$target" > "$tmp" 2>/dev/null; then
    printf '  - %s: not valid JSON for jq; left unchanged\n' "$target" >&2
    rm -f "$tmp"
    return 0
  fi
  if cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    printf '  = %s: already up to date\n' "$target"
    return 0
  fi
  mv "$tmp" "$target"
  chmod 600 "$target" 2>/dev/null || true
  printf '  + %s: topped up from %s (existing keys kept)\n' "$target" "$tpl"
}

cfg="$(opencode_cfg_target)"
seed "$TEMPLATES/opencode.json" "$cfg" "opencode config"

cli="$(cli_cfg)"
seed "$TEMPLATES/cli.json" "$cli" "opencode cli config"

if ! opencode_cfg >/dev/null; then
  printf '  - opencode: no server config found after seeding\n' >&2
fi
