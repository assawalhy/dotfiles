#!/usr/bin/env bash
# Interactive installer for agent skills & plugins (catalog: agent-skills.list),
# plus the shared AGENTS.md context wiring.
#
#   setup/agent-skills.sh                interactive catalog picker, then wire context
#   setup/agent-skills.sh --all          install every catalog item, no prompt
#   setup/agent-skills.sh --list         print the catalog with installed markers
#   setup/agent-skills.sh --dry-run      print what --all would run, without running
#   setup/agent-skills.sh --context      print how committed context files are wired
#
# The catalog installs harness-agnostic skills into ~/.agents/skills (read by
# pi, Claude Code, Codex, Gemini CLI, kilo, ...), plus per-harness packages and
# plugins (install field is a shell command per category). The awesome-agent
# plugin (catalog entry `plugin|awesome-agent`) installs its own
# commands/agents/skills into every harness dir itself (claude, pi prompts,
# cursor, codex, opencode, ...) — dotfiles does NOT mirror those.
#
# Authored context files (common/.agents/AGENTS.md, common/.claude/CLAUDE.md)
# are dotfiles, symlinked by link-files — this script never wires them.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$REPO/setup/agent-skills.list"
SKILLS_DIR="${AGENT_SKILLS_DIR:-$HOME/.agents/skills}"

usage() {
  sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

mode=interactive
for a in "$@"; do
  case "$a" in
    --all|-y|--yes)          mode=all ;;
    --list)                  mode=list ;;
    --dry-run)               mode=dry ;;
    --context|--context-only) mode=context ;;
    -h|--help)               usage; exit 0 ;;
    *) echo "unknown option: $a" >&2; usage >&2; exit 1 ;;
  esac
done

# --------------------------------------------------------- catalog ---

cat_=(); id_=(); desc_=(); inst_=(); N=0
load_catalog() {
  [ -f "$LIST" ] || { echo "catalog not found: $LIST" >&2; exit 1; }
  while IFS='|' read -r c i d ins || [ -n "$c" ]; do
    case "$c" in ''|'#'*) continue ;; esac
    cat_[$N]="$c"; id_[$N]="$i"; desc_[$N]="$d"; inst_[$N]="$ins"
    N=$((N + 1))
  done < "$LIST"
}

# installed_path <idx> -> path if installed, empty otherwise
installed_path() {
  local c="${cat_[$1]}" i="${id_[$1]}"
  case "$c/$i" in
    agents-skill/*|vendored-skill/*)
      [ -d "$SKILLS_DIR/$i" ] && printf '%s' "$SKILLS_DIR/$i" ;;
    plugin/awesome-agent)
      [ -f "$HOME/.local/share/awesome-agent/registry.txt" ] \
        && printf '%s' "$HOME/.local/share/awesome-agent/registry.txt" ;;
    pi-package/tmustier-pi-extensions)
      [ -d "$HOME/.pi/agent/git/github.com/tmustier/pi-extensions" ] \
        && printf '%s' "$HOME/.pi/agent/git/github.com/tmustier/pi-extensions" ;;
    pi-package/plannotator)
      [ -d "$HOME/.pi/agent/npm/node_modules/@plannotator/pi-extension" ] \
        && printf '%s' "$HOME/.pi/agent/npm/node_modules/@plannotator/pi-extension" ;;
    claude-plugin/*)
      if [ -f "$HOME/.claude/plugins/installed_plugins.json" ] \
         && grep -q "\"$i\"" "$HOME/.claude/plugins/installed_plugins.json"; then
        printf '%s' '~/.claude/plugins/installed_plugins.json'
      fi ;;
    codex-plugin/*)
      if [ -f "$HOME/.codex/config.toml" ] \
         && grep -q "\[plugins\.\"$i\"\]" "$HOME/.codex/config.toml"; then
        printf '%s' '~/.codex/config.toml'
      fi ;;
    agent-tool/*)
      local st
      st="$(bash "$REPO/setup/agent-tools.sh" status "$i" 2>/dev/null || true)"
      [ -n "$st" ] && printf '%s' "$st" ;;
  esac
  return 0
}

print_catalog() {
  local k=0 last='' p
  while [ "$k" -lt "$N" ]; do
    if [ "${cat_[$k]}" != "$last" ]; then
      printf '\n  ---- %s ----\n' "${cat_[$k]}"
      last="${cat_[$k]}"
    fi
    p="$(installed_path "$k")"
    if [ -n "$p" ]; then printf '  [x] %2d. %-28s %s\n' "$((k+1))" "${id_[$k]}" "${desc_[$k]}"; \
    else                   printf '  [ ] %2d. %-28s %s\n' "$((k+1))" "${id_[$k]}" "${desc_[$k]}"; fi
    k=$((k + 1))
  done
}

# expand_selection <count> <input> -> selected 1-based indices, one per line
# numbers, "lo-hi" ranges, "a"/"all" or empty = all, "n"/"none" = none.
# Commas and spaces both separate tokens, so "1,3 5-7" picks 1,3,5,6,7.
expand_selection() {
  local n="$1" sel="$2" tok lo hi i
  case "$sel" in
    n|N|none) return ;;
    a|A|all|'') i=1; while [ "$i" -le "$n" ]; do printf '%s\n' "$i"; i=$((i + 1)); done; return ;;
  esac
  sel="$(printf '%s' "$sel" | tr ',' ' ')"
  for tok in $sel; do
    case "$tok" in
      *-*) lo="${tok%%-*}"; hi="${tok##*-}" ;;
      *)   lo="$tok"; hi="$tok" ;;
    esac
    case "$lo$hi" in
      ''|*[!0-9]*) printf 'ignoring "%s"\n' "$tok" >&2; continue ;;
    esac
    i="$lo"
    while [ "$i" -le "$hi" ]; do
      if [ "$i" -ge 1 ] && [ "$i" -le "$n" ]; then printf '%s\n' "$i"; fi
      i=$((i + 1))
    done
  done
}

# --------------------------------------------------------- install ---

install_one() {
  local c="${cat_[$1]}" i="${id_[$1]}" ins="${inst_[$1]}"
  local url dir base tmp
  case "$c" in
    plugin)
      url="$ins"
      # split: bash expands every word before `local` assigns, so chaining
      # repodir="$plugdir/repo" trips `set -u` (unbound plugdir).
      local plugdir="$HOME/.local/share/awesome-agent"
      local repodir="$plugdir/repo"
      if [ -d "$repodir/.git" ]; then
        printf -- '+ git -C %s pull --ff-only\n' "$repodir"
        git -C "$repodir" pull --ff-only
      else
        printf -- '+ git clone --depth 1 %s\n' "$url"
        mkdir -p "$plugdir"
        git clone --depth 1 "$url" "$repodir"
      fi
      if [ -t 0 ]; then
        printf -- '+ bash %s/install.sh (interactive TUI)\n' "$repodir"
        ( cd "$repodir" && bash install.sh )
      else
        printf -- '+ bash %s/install.sh --all\n' "$repodir"
        ( cd "$repodir" && bash install.sh --all )
      fi
      ;;
    agents-skill)
      url="${ins%%@*}"; dir="${ins#*@}"
      base="$(basename "$url" .git)"
      tmp="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills.XXXXXX")"
      printf -- '+ git clone --depth 1 %s\n' "$url"
      git clone --depth 1 "$url" "$tmp/$base"
      mkdir -p "$SKILLS_DIR"
      cp -R "$tmp/$base/$dir" "$SKILLS_DIR/$i"
      rm -rf "$tmp"
      ;;
    vendored-skill)
      printf -- '+ cp -R setup/skills/%s -> %s\n' "$i" "$SKILLS_DIR/$i"
      mkdir -p "$SKILLS_DIR"
      cp -R "$REPO/setup/skills/$i" "$SKILLS_DIR/$i"
      ;;
    agent-tool)
      printf -- '+ bash setup/agent-tools.sh install %s\n' "$i"
      bash "$REPO/setup/agent-tools.sh" install "$i"
      ;;
    *)
      printf -- '+ %s\n' "$ins"
      ( eval "$ins" ) ;;
  esac
  printf -- '  installed: %s (%s)\n' "$i" "$c"
}

run_all() {
  local k=0 rc=0
  while [ "$k" -lt "$N" ]; do
    if [ -z "$(installed_path "$k")" ]; then
      printf '\n# %s — %s\n' "${id_[$k]}" "${desc_[$k]}"
      # subshell re-enables errexit so install_one stops at its own first
      # bad step; run under the caller's `set +e` so one failed item skips
      # only itself instead of aborting the rest of the catalog.
      ( set -e; install_one "$k" )
      if [ $? -ne 0 ]; then
        printf '! failed: %s\n' "${id_[$k]}" >&2
        rc=1
      fi
    else
      printf '# %s — already installed, skipped\n' "${id_[$k]}"
    fi
    k=$((k + 1))
  done
  if [ "$rc" -ne 0 ]; then
    printf '\nsome items failed (see ! lines); fix and re-run.\n' >&2
  fi
  return "$rc"
}

dry_run_all() {
  local k=0
  while [ "$k" -lt "$N" ]; do
    if [ -z "$(installed_path "$k")" ]; then
      printf '%s\t%s\t%s\n' "${cat_[$k]}" "${id_[$k]}" "${inst_[$k]}"
    else
      printf '%s\t%s\t(already installed)\n' "${cat_[$k]}" "${id_[$k]}"
    fi
    k=$((k + 1))
  done
}

# --------------------------------------------------- context hint ---

context_hint() {
  printf -- 'Committed context files are dotfiles, symlinked by link-files:\n'
  printf -- '  common/.agents/AGENTS.md -> ~/.agents/AGENTS.md\n'
  printf -- '  common/.claude/CLAUDE.md -> ~/.claude/CLAUDE.md\n'
  printf -- 'Run: bash link-files.bash --fix\n'
}

# ----------------------------------------------------------- main ---

load_catalog

case "$mode" in
  list) print_catalog ;;
  dry)  dry_run_all ;;
  all)
    set +e          # let a failed item skip itself, not the whole catalog
    run_all; rc=$?
    context_hint
    set -e
    exit "$rc"
    ;;
  context)
    context_hint
    ;;
  interactive)
    if [ ! -t 0 ]; then
      print_catalog
      printf '\nstdin is not a tty; run with --all or --context to act.\n'
      exit 0
    fi
    print_catalog
    printf '\nSelect items (numbers/ranges, comma or space separated, "a"=all, "n"=none, empty=all): '
    read -r sel || sel=''
    picked="$(expand_selection "$N" "$sel")"
    if [ -z "$picked" ]; then
      printf 'Nothing selected.\n'
    else
      set +e
      for k in $picked; do
        printf '\n# %s — %s\n' "${id_[$((k-1))]}" "${desc_[$((k-1))]}"
        ( set -e; install_one "$((k-1))" )
        [ $? -ne 0 ] && printf '! failed: %s\n' "${id_[$((k-1))]}" >&2
      done
      set -e
    fi
    printf '\n'
    context_hint
    ;;
esac

exit 0