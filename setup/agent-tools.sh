#!/usr/bin/env bash
# Multi-harness tool installer: one catalog entry per tool installs the tool
# into every harness present on the machine (opencode, claude, codex, pi,
# cursor, kiro, kilo, gemini, ...). Install steps are idempotent and guarded
# per harness: a missing client is skipped, not fatal.
#
#   setup/agent-tools.sh install <tool>   install <tool> into every harness present
#   setup/agent-tools.sh status <tool>    print a marker path when <tool> is
#                                         configured in every harness present,
#                                         print nothing otherwise; exits 0
#
# Tools: context7 (MCP docs), plannotator (plan/code review), typescript-lsp
# (Claude Code LSP speedups), graphify (knowledge-graph CLI + per-harness skill).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="${1:-install}"
TOOL="${2:-}"

# ---- harness detection (mirrors awesome-agent install.sh) ----

harness_present() {
  case "$1" in
    opencode) [ -d "$HOME/.config/opencode" ] || command -v opencode >/dev/null 2>&1 ;;
    claude)   [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1 ;;
    codex)    [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1 ;;
    pi)       [ -d "$HOME/.pi/agent" ] || command -v pi >/dev/null 2>&1 ;;
    cursor)   [ -d "$HOME/.cursor" ] || command -v cursor >/dev/null 2>&1 ;;
    kiro)     [ -d "$HOME/.kiro" ] || command -v kiro-cli >/dev/null 2>&1 ;;
    kilo)     [ -d "$HOME/.kilocode" ] || command -v kilo >/dev/null 2>&1 ;;
    gemini)   [ -d "$HOME/.gemini" ] || command -v gemini >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# helper: guard a step behind a harness + optional binary
run_harness() { # <harness> <binary> <cmd...>
  local h="$1" bin="$2"; shift 2
  harness_present "$h" || return 0
  if [ -n "$bin" ] && ! command -v "$bin" >/dev/null 2>&1; then
    printf '  - %s: %s not on PATH, skipped\n' "$h" "$bin"
    return 0
  fi
  "$@"
}

# Runner guard: skip a step when the harness binary is missing
harness_status_print() { [ -n "${1:-}" ] && printf '%s\n' "$1"; }

# jq_add_key <path> <jq-assignment>
# Adds/overwrites ONE key in a JSON config with jq, preserving every other
# key (default_agent, plugin arrays, hooks, ...) verbatim. Never links the
# file and never writes when jq cannot parse the existing file.
jq_add_key() {
  local p="$1" assign="$2" tmp
  [ -f "$p" ] || { printf '  - %s missing, nothing to edit\n' "$p"; return 0; }
  command -v jq >/dev/null 2>&1 || { printf '  - jq missing, cannot edit %s\n' "$p"; return 0; }
  tmp="$(mktemp "${TMPDIR:-/tmp}/agent-tools.XXXXXX")" || return 0
  if ! jq --indent 2 "$assign" "$p" > "$tmp" 2>/dev/null; then
    printf '  - %s: not valid JSON for jq; left unchanged\n' "$p"
    rm -f "$tmp"
    return 0
  fi
  mv "$tmp" "$p"
  printf '  + %s: key updated via jq\n' "$p"
}

# ---- context7: MCP docs server, all MCP-capable harnesses ----

opencode_cfg() {
  for f in "$HOME/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode.jsonc" "$HOME/.config/opencode.json"; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

context7_opencode_install() {
  local cfg
  cfg="$(opencode_cfg)" || return 0
  jq_add_key "$cfg" '.mcp.context7 = {"type":"local","command":["npx","-y","@upstash/context7-mcp"],"enabled":true}'
}
context7_opencode_status() {
  local cfg
  cfg="$(opencode_cfg)" || return 1
  grep -q '"context7"' "$cfg"
}

context7_codex_install() {
  local cfg="$HOME/.codex/config.toml"
  [ -f "$cfg" ] || return 0
  grep -q '\[mcp_servers.context7\]' "$cfg" && return 0
  printf '\n[mcp_servers.context7]\ncommand = "npx"\nargs = ["-y", "@upstash/context7-mcp"]\n' >> "$cfg"
  printf '  + codex: context7 MCP added to %s\n' "$cfg"
}
context7_codex_status() {
  [ -f "$HOME/.codex/config.toml" ] && grep -q '\[mcp_servers.context7\]' "$HOME/.codex/config.toml"
}

context7_cursor_install() {
  local p="$HOME/.cursor/mcp.json"
  mkdir -p "$HOME/.cursor"
  if [ ! -f "$p" ]; then
    printf '{\n  "mcpServers": {}\n}\n' > "$p"
  fi
  jq_add_key "$p" '.mcpServers.context7 = {"command":"npx","args":["-y","@upstash/context7-mcp"]}'
}
context7_cursor_status() {
  [ -f "$HOME/.cursor/mcp.json" ] && grep -q '"context7"' "$HOME/.cursor/mcp.json"
}

context7_claude_install() {
  run_harness claude claude claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null
  run_harness claude claude claude plugin install context7@claude-plugins-official 2>/dev/null
}
context7_claude_status() {
  grep -q '"context7@claude-plugins-official"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null
}

context7_pi_install() {
  run_harness pi pi pi install npm:@upstash/context7-pi 2>/dev/null
}
context7_pi_status() {
  [ -d "$HOME/.pi/agent/npm/node_modules/@upstash/context7-pi" ]
}

context7_install() { context7_opencode_install; context7_codex_install; context7_cursor_install; context7_claude_install; context7_pi_install; }
context7_status() {
  local ok=0 missing=0
  harness_present opencode && { context7_opencode_status && ok=$((ok+1)) || missing=$((missing+1)); }
  harness_present codex   && { context7_codex_status   && ok=$((ok+1)) || missing=$((missing+1)); }
  harness_present cursor  && { context7_cursor_status  && ok=$((ok+1)) || missing=$((missing+1)); }
  harness_present claude  && { context7_claude_status  && ok=$((ok+1)) || missing=$((missing+1)); }
  harness_present pi      && { context7_pi_status      && ok=$((ok+1)) || missing=$((missing+1)); }
  [ "$missing" -eq 0 ] && [ "$ok" -gt 0 ] && printf '%s\n' "$HOME/.agents/tools/context7"
}

# ---- plannotator: plan & code review ----

# plannotator ships as a 150+ MB CLI plus a sem sidecar and an agent-terminal
# runtime; the official installer owns all of it (binary, sidecar, runtime,
# hooks, skills, commands). Run it non-interactively so setup-os never blocks
# on its /dev/tty wizard, keep its output (a failed download must not look
# like success), and verify the binary actually landed.
plannotator_bin_install() {
  local bin="$HOME/.local/bin/plannotator" log
  [ -x "$bin" ] && return 0
  command -v plannotator >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 || { printf '  - plannotator: curl missing, cannot install\n' >&2; return 1; }
  log="$(mktemp "${TMPDIR:-/tmp}/plannotator.XXXXXX")" || log=/dev/null
  printf '  + plannotator: official installer (binary + sem sidecar + runtimes + agent hooks, ~150 MB; this takes a few minutes)\n'
  curl -fsSL https://plannotator.ai/install.sh | bash -s -- --non-interactive >"$log" 2>&1 || true
  if [ -x "$bin" ] || command -v plannotator >/dev/null 2>&1; then
    printf '  + plannotator: binary installed\n'
    rm -f "$log"
    return 0
  fi
  printf '  - plannotator: binary not found after the official installer failed\n' >&2
  [ "$log" != /dev/null ] && tail -n 15 "$log" >&2
  rm -f "$log"
  return 1
}

plannotator_opencode_install() {
  run_harness opencode opencode opencode plugin add @plannotator/opencode@latest 2>/dev/null
}
plannotator_opencode_status() {
  local cfg
  cfg="$(opencode_cfg)" || return 1
  grep -q '@plannotator/opencode' "$cfg"
}

plannotator_claude_install() {
  run_harness claude claude claude plugin marketplace add backnotprop/plannotator 2>/dev/null
  run_harness claude claude claude plugin install plannotator@plannotator 2>/dev/null
}
plannotator_claude_status() {
  grep -q '"plannotator@plannotator"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null
}

plannotator_pi_install() {
  run_harness pi pi pi install npm:@plannotator/pi-extension 2>/dev/null
}
plannotator_pi_status() {
  [ -d "$HOME/.pi/agent/npm/node_modules/@plannotator/pi-extension" ]
}

plannotator_install() {
  local rc=0
  plannotator_bin_install || rc=1
  plannotator_opencode_install
  plannotator_claude_install
  plannotator_pi_install
  # codex/kiro/gemini integrations are created by the official installer above.
  return "$rc"
}
plannotator_status() {
  local bin="$HOME/.local/bin/plannotator" klaus=1
  { [ -x "$bin" ] || command -v plannotator >/dev/null 2>&1; } || klaus=0
  harness_present opencode && { plannotator_opencode_status && : || klaus=0; }
  harness_present claude   && { plannotator_claude_status   && : || klaus=0; }
  harness_present pi       && { plannotator_pi_status       && : || klaus=0; }
  [ "$klaus" -eq 1 ] && printf '%s\n' "$HOME/.agents/tools/plannotator"
}

# ---- typescript-lsp: Claude Code LSP speedups (claude-only upstream) ----

typescript_lsp_install() {
  run_harness claude claude claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null
  run_harness claude claude claude plugin install typescript-lsp@claude-plugins-official 2>/dev/null
}
typescript_lsp_status() {
  grep -q '"typescript-lsp@claude-plugins-official"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null \
    && printf '%s\n' "$HOME/.agents/tools/typescript-lsp"
}

# ---- graphify: any input to a persistent knowledge graph ----
# Ships as PyPI graphifyy; the wheel bundles SKILL.md + references/,
# `graphify install --platform <p>` copies them per harness.

GRAPHIFY_PLATFORMS="opencode claude codex pi kiro kilo gemini cursor"

graphify_skill_path() { # <platform> -> path of installed SKILL.md
  case "$1" in
    opencode) printf '%s\n' "$HOME/.config/opencode/skills/graphify/SKILL.md" ;;
    claude)   printf '%s\n' "$HOME/.claude/skills/graphify/SKILL.md" ;;
    codex)    printf '%s\n' "$HOME/.codex/skills/graphify/SKILL.md" ;;
    pi)       printf '%s\n' "$HOME/.pi/agent/skills/graphify/SKILL.md" ;;
    kiro)     printf '%s\n' "$HOME/.kiro/skills/graphify/SKILL.md" ;;
    kilo)     printf '%s\n' "$HOME/.config/kilo/skills/graphify/SKILL.md" ;;
    gemini)   printf '%s\n' "$HOME/.gemini/skills/graphify/SKILL.md" ;;
    cursor)   printf '%s\n' "$HOME/.cursor/rules/graphify.mdc" ;;
    *) return 1 ;;
  esac
}

graphify_bin_install() {
  local bin="$HOME/.local/bin/graphify"
  { [ -x "$bin" ] || command -v graphify >/dev/null 2>&1; } && return 0
  if command -v uv >/dev/null 2>&1; then
    printf '  + graphify: installing graphifyy via uv tool\n'
    if uv tool install -q graphifyy[sql] || uv tool install -q graphifyy; then
      return 0
    fi
    printf '  - graphify: uv tool install failed\n' >&2
  elif command -v pipx >/dev/null 2>&1; then
    printf '  + graphify: installing graphifyy via pipx\n'
    if pipx install -q graphifyy; then
      return 0
    fi
    printf '  - graphify: pipx install failed\n' >&2
  else
    printf '  - graphify: need uv or pipx to install graphifyy (it owns its own installer)\n' >&2
  fi
  [ -x "$bin" ] || command -v graphify >/dev/null 2>&1
}

graphify_platform_install() {
  local p="$1" sp log
  # Non-project opencode/cursor installs write plugin/rule files relative to
  # CWD; run from $HOME so they land under the home dir, never in a repo.
  log="$(mktemp "${TMPDIR:-/tmp}/graphify.XXXXXX")" || log=/dev/null
  (cd "$HOME" && graphify install --platform "$p") >"$log" 2>&1
  sp="$(graphify_skill_path "$p")" || sp=""
  if [ -n "$sp" ] && [ -f "$sp" ]; then
    printf '  + graphify: skill installed for %s\n' "$p"
  else
    printf '  - graphify: %s install failed (no %s)\n' "$p" "${sp:-skill file}" >&2
    [ "$log" != /dev/null ] && tail -n 5 "$log" >&2
  fi
  rm -f "$log"
}

graphify_install() {
  graphify_bin_install || return 1
  local p
  for p in $GRAPHIFY_PLATFORMS; do
    harness_present "$p" && graphify_platform_install "$p"
  done
  return 0
}

graphify_status() {
  { [ -x "$HOME/.local/bin/graphify" ] || command -v graphify >/dev/null 2>&1; } || return 1
  local ok=0 missing=0 p sp
  for p in $GRAPHIFY_PLATFORMS; do
    harness_present "$p" || continue
    sp="$(graphify_skill_path "$p")" && [ -f "$sp" ] && ok=$((ok+1)) || missing=$((missing+1))
  done
  [ "$missing" -eq 0 ] && [ "$ok" -gt 0 ] && printf '%s\n' "$HOME/.agents/tools/graphify"
}

# ---- dispatch ----
# install failures propagate (agent-skills.sh turns them into "! failed");
# status always exits 0 per the contract above.

rc=0
case "$CMD:$TOOL" in
  install:context7)      context7_install; rc=$? ;;
  status:context7)       context7_status ;;
  install:plannotator)   plannotator_install; rc=$? ;;
  status:plannotator)    plannotator_status ;;
  install:typescript-lsp) typescript_lsp_install; rc=$? ;;
  status:typescript-lsp) typescript_lsp_status ;;
  install:graphify)      graphify_install; rc=$? ;;
  status:graphify)       graphify_status ;;
  *)
    printf 'usage: setup/agent-tools.sh <install|status> <context7|plannotator|typescript-lsp|graphify>\n' >&2
    exit 1 ;;
esac

exit "$rc"