#!/usr/bin/env bash
# Interactive installer for agent skills & plugins (catalog: agent-skills.list),
# plus the shared AGENTS.md context wiring.
#
#   setup/agent-skills.sh                interactive catalog picker, then wire context
#   setup/agent-skills.sh --all          install every catalog item, no prompt
#   setup/agent-skills.sh --list         print the catalog with installed markers
#   setup/agent-skills.sh --dry-run      print what --all would run, without running
#   setup/agent-skills.sh --context      only (re)wire the shared context files
#
# The catalog installs harness-agnostic skills into ~/.agents/skills (read by
# pi, Claude Code, Codex, Gemini CLI, kilo, ...), plus per-harness packages and
# plugins. The awesome-agent plugin (catalog entry `plugin|awesome-agent`)
# installs its own commands/agents/skills into every harness dir itself
# (claude, pi prompts, cursor, codex, opencode, ...) — dotfiles does NOT mirror
# those. The only committed context file is common/.agents/AGENTS.md, wired
# to ~/.agents/AGENTS.md below.
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
  esac
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
expand_selection() {
  local n="$1" sel="$2" tok lo hi i
  case "$sel" in
    n|N|none) return ;;
    a|A|all|'') i=1; while [ "$i" -le "$n" ]; do printf '%s\n' "$i"; i=$((i + 1)); done; return ;;
  esac
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
      local plugdir="$HOME/.local/share/awesome-agent" repodir="$plugdir/repo"
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
    *)
      printf -- '+ %s\n' "$ins"
      ( eval "$ins" ) ;;
  esac
  printf -- '  installed: %s (%s)\n' "$i" "$c"
}

run_all() {
  local k=0
  while [ "$k" -lt "$N" ]; do
    if [ -z "$(installed_path "$k")" ]; then
      printf '\n# %s — %s\n' "${id_[$k]}" "${desc_[$k]}"
      install_one "$k"
    else
      printf '# %s — already installed, skipped\n' "${id_[$k]}"
    fi
    k=$((k + 1))
  done
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

# --------------------------------------------------- context wire ---

# link_if_needed <home-relpath> <repo-common-relpath>
link_if_needed() {
  local dest="$HOME/$1" src="$REPO/common/$2" bak
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    printf '  = %s (ok)\n' "$1"
  elif [ -e "$dest" ]; then
    if [ -L "$dest" ] || ! cmp -s "$dest" "$src"; then
      mkdir -p "$BACKUP_DIR"
      bak="$BACKUP_DIR/$(basename "$dest")"
      [ -e "$bak" ] && rm -rf "$bak"
      mv "$dest" "$bak"
      printf '  ~ %s (backed up to %s)\n' "$1" "$bak"
    else
      rm "$dest"
      printf '  ~ %s (replaced identical file)\n' "$1"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
  else
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    printf '  + %s\n' "$1"
  fi
}

wire_context() {
  local pairs=( ".agents/AGENTS.md|.agents/AGENTS.md" )
  local p
  printf -- 'Wiring shared context files:\n'
  for p in "${pairs[@]}"; do
    link_if_needed "${p%%|*}" "${p#*|}"
  done
}

# ----------------------------------------------------------- main ---

load_catalog
BACKUP_DIR="$HOME/.agent-context-backup-$(date +%Y%m%d-%H%M%S)"

case "$mode" in
  list) print_catalog ;;
  dry)  dry_run_all ;;
  all)
    run_all
    wire_context
    ;;
  context)
    wire_context
    ;;
  interactive)
    if [ ! -t 0 ]; then
      print_catalog
      printf '\nstdin is not a tty; run with --all or --context to act.\n'
      exit 0
    fi
    print_catalog
    printf '\nSelect items (numbers/ranges, "a"=all, "n"=none, empty=all): '
    read -r sel || sel=''
    picked="$(expand_selection "$N" "$sel")"
    if [ -z "$picked" ]; then
      printf 'Nothing selected.\n'
    else
      for k in $picked; do
        printf '\n# %s — %s\n' "${id_[$((k-1))]}" "${desc_[$((k-1))]}"
        install_one "$((k-1))"
      done
    fi
    printf '\n'
    wire_context
    ;;
esac

exit 0