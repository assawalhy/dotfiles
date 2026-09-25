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
# Tools: context7 (MCP docs), plannotator (plan/code review), warp (terminal
# notifications), typescript-lsp (Claude Code LSP speedups), graphify
# (knowledge-graph skill; installs via its own `graphify install`).
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

plannotator_bin_install() {
  command -v plannotator >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 || { printf '  - curl missing, cannot install plannotator\n'; return 0; }
  printf '  + plannotator: running official installer (auto-detects claude/codex/opencode/pi/kiro/gemini/copilot/droid/amp)\n'
  curl -fsSL https://plannotator.ai/install.sh | bash 2>/dev/null
}

plannotator_opencode_install() {
  run_harness opencode opencode opencode plugin @plannotator/opencode@latest 2>/dev/null
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
  plannotator_bin_install
  plannotator_opencode_install
  plannotator_claude_install
  plannotator_pi_install
  # codex/kiro/gemini integrations are created by the official installer above.
}
plannotator_status() {
  local klaus=1
  command -v plannotator >/dev/null 2>&1 || klaus=0
  harness_present opencode && { plannotator_opencode_status && : || klaus=0; }
  harness_present claude   && { plannotator_claude_status   && : || klaus=0; }
  harness_present pi       && { plannotator_pi_status       && : || klaus=0; }
  [ "$klaus" -eq 1 ] && printf '%s\n' "$HOME/.agents/tools/plannotator"
}

# ---- warp: terminal notifications ----

warp_claude_install() {
  run_harness claude claude claude plugin marketplace add warpdotdev/claude-code-warp 2>/dev/null
  run_harness claude claude claude plugin install warp@claude-code-warp 2>/dev/null
}
warp_claude_status() {
  grep -q '"warp@claude-code-warp"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null
}

warp_codex_install() {
  run_harness codex codex codex plugin marketplace add warpdotdev/codex-warp 2>/dev/null
  run_harness codex codex codex plugin add warp@codex-warp 2>/dev/null
}
warp_codex_status() {
  grep -q 'warp@codex-warp' "$HOME/.codex/config.toml" 2>/dev/null
}

warp_install() { warp_claude_install; warp_codex_install; }
warp_status() {
  local ok=0 missing=0
  harness_present claude && { warp_claude_status && ok=$((ok+1)) || missing=$((missing+1)); }
  harness_present codex  && { warp_codex_status  && ok=$((ok+1)) || missing=$((missing+1)); }
  [ "$missing" -eq 0 ] && [ "$ok" -gt 0 ] && printf '%s\n' "$HOME/.agents/tools/warp"
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
  command -v graphify >/dev/null 2>&1 && return 0
  if command -v uv >/dev/null 2>&1; then
    printf '  + graphify: installing graphifyy via uv tool\n'
    uv tool install -q graphifyy[sql] 2>/dev/null || \
      uv tool install -q graphifyy 2>/dev/null || \
      { printf '  - graphify: uv tool install failed\n'; return 0; }
  elif command -v pipx >/dev/null 2>&1; then
    printf '  + graphify: installing graphifyy via pipx\n'
    pipx install -q graphifyy 2>/dev/null || { printf '  - graphify: pipx install failed\n'; return 0; }
  else
    printf '  - graphify: need uv or pipx to install graphifyy (it owns its own installer)\n'
    return 0
  fi
}

graphify_platform_install() {
  local p="$1"
  # Non-project opencode/cursor installs write plugin/rule files relative to
  # CWD; run from $HOME so they land under the home dir, never in a repo.
  (cd "$HOME" && graphify install --platform "$p") >/dev/null 2>&1 \
    && printf '  + graphify: skill installed for %s\n' "$p" \
    || printf '  - graphify: %s install failed\n' "$p"
}

graphify_install() {
  graphify_bin_install
  command -v graphify >/dev/null 2>&1 || return 0
  local p
  for p in $GRAPHIFY_PLATFORMS; do
    harness_present "$p" && graphify_platform_install "$p"
  done
}

graphify_status() {
  command -v graphify >/dev/null 2>&1 || return 1
  local ok=0 missing=0 p sp
  for p in $GRAPHIFY_PLATFORMS; do
    harness_present "$p" || continue
    sp="$(graphify_skill_path "$p")" && [ -f "$sp" ] && ok=$((ok+1)) || missing=$((missing+1))
  done
  [ "$missing" -eq 0 ] && [ "$ok" -gt 0 ] && printf '%s\n' "$HOME/.agents/tools/graphify"
}

# ---- dispatch ----

case "$CMD:$TOOL" in
  install:context7)      context7_install ;;
  status:context7)       context7_status ;;
  install:plannotator)   plannotator_install ;;
  status:plannotator)    plannotator_status ;;
  install:warp)          warp_install ;;
  status:warp)           warp_status ;;
  install:typescript-lsp) typescript_lsp_install ;;
  status:typescript-lsp) typescript_lsp_status ;;
  install:graphify)      graphify_install ;;
  status:graphify)       graphify_status ;;
  *)
    printf 'usage: setup/agent-tools.sh <install|status> <context7|plannotator|warp|typescript-lsp|graphify>\n' >&2
    exit 1 ;;
esac

exit 0