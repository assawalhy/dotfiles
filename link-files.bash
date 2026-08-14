#!/usr/bin/env bash
#
# link-files.bash -- symlink this repo's dotfiles into $HOME (macOS + Linux).
#
# Sources are  <repo>/common  and  <repo>/<os>  where <os> is linux or macos.
# On a path collision the OS overlay wins. The repo is the source of truth;
# --refresh captures new files that appeared inside linked dirs back into the
# repo and symlinks them in place (see --reverse below).
#
# NOTE: must stay bash 3.2 compatible -- stock macOS /bin/bash is 3.2.57.
#       No readarray/mapfile, no `declare -A`, no ${v,,}, no globstar.
#       The file lister is pure bash + POSIX find/awk/sort -- no node.

PS4='$LINENO: '
set -e

# ---------------------------------------------------------------- OS ---

case "$(uname -s)" in
  Linux)  OS=linux  ;;
  Darwin) OS=macos  ;;
  *) printf 'unsupported OS: %s (expected Linux or Darwin)\n' "$(uname -s)" >&2; exit 1 ;;
esac

# ------------------------------------------------------------- paths ---

# Resolve the repo from this script's own location, never from $PWD, so the
# script works from any directory. realpath(1) is avoided (missing on older
# macOS); this is the portable symlink-walking idiom.
self="$0"
while [ -L "$self" ]; do
  self_dir="$(cd -P "$(dirname "$self")" >/dev/null && pwd)"
  self="$(readlink "$self")"
  case "$self" in /*) ;; *) self="$self_dir/$self" ;; esac
done
REPO="$(cd -P "$(dirname "$self")" >/dev/null && pwd)"

COMMON="$REPO/common"
OSDIR="$REPO/$OS"
IGNORE_FILE="$REPO/link-ignore.txt"
CTX_FILE="$REPO/link-context.txt"
STAMP="$(date +%Y%m%d%H%M%S)"

# --------------------------------------------------------------- cli ---

is_help=; is_force=; is_no_backup=; is_dry=; is_yes=; is_refresh=; is_audit=; filter=; pattern_given=

print_help() {
cat <<EOF
USAGE:
  $(basename "$0") [--help] [--force] [--no-backup] [--dry-run] [--yes] [--refresh] [--audit] [filtering_pattern]
  $(basename "$0") --force '.*nvim/lua.*'
  $(basename "$0") --refresh --dry-run
  $(basename "$0") --audit

Symlinks $COMMON and $OSDIR into \$HOME.
Detected OS: $OS

OPTIONS:
  -h, --help      show this message and exit
      --force     resolve conflicts: replace foreign symlinks, and back up
                  real files to <file>.bak.<timestamp> before linking
      --no-backup with --force, delete a conflicting real file instead of
                  backing it up to <file>.bak.<timestamp>; refuses to
                  replace a directory; requires --force
  -n, --dry-run   show what would happen, then exit without changing anything
  -y, --yes       skip the confirmation prompt
      --refresh   capture new files that appeared inside linked dirs into the
                  repo (OS overlay first, else common) and symlink them back;
                  never overwrites repo files; --force has no effect
      --audit     read-only link-drift report: repo files lacking a correct
                  home link (missing/relink/conflict/stale) plus real files
                  in linked dirs absent from the repo. Applies the
                  link-context.txt neglect list for the current session
                  (wayland/x11/headless). Exit 0 = clean, 1 = findings;
                  never writes, no picker, no prompt
  <pattern>       extended regex; only paths matching it are considered

INTERACTIVE SELECTION:
  Run bare (no --dry-run, --yes, --refresh, --audit or pattern) to choose exactly which
  files to link. With fzf on a terminal: TAB toggles one entry, CTRL-A selects
  all matches, CTRL-D clears the selection, ENTER links. Without fzf -- or
  when stdin is not a terminal -- a numbered menu is shown instead: 'a'
  selects all (the default), 'n' selects none, numbers and ranges pick
  specific files, and an empty answer selects everything.

MARKERS IN THE PREVIEW:
  +  new link
  *  fixed in place (old hard link, or a link pointing at the wrong source)
  ~  conflict resolved via --force (existing file is backed up first)
  !  conflict -- needs --force
  -  stale link into this repo, will be removed
EOF
}

parse_args() {
  for o in "$@"; do
    case "$o" in
      -h|--help)    is_help=1; break ;;
      --force)      is_force=1; continue ;;
      -n|--dry-run) is_dry=1;   continue ;;
      -y|--yes)     is_yes=1;   continue ;;
      --refresh)    is_refresh=1; continue ;;
      --audit)      is_audit=1;   continue ;;
      --no-backup)  is_no_backup=1; continue ;;
      -r|--reverse)
        printf -- '--reverse was removed: the repo is now the source of truth.\n' >&2
        printf -- 'To adopt a file from $HOME:  mv ~/.foo %s/.foo && %s\n' \
          "$(basename "$COMMON")" "$(basename "$0")" >&2
        exit 1 ;;
      -*)
        printf 'unknown option "%s"\n' "$o" >&2; exit 1 ;;
      *)
        if [ -n "$filter" ]; then
          printf 'you can only specify one filtering pattern\n' >&2; exit 1
        fi
        filter="$o"; pattern_given=1 ;;
    esac
  done

  if [ -n "$is_help" ]; then print_help; exit 0; fi
  if [ -n "$is_no_backup" ] && [ -z "$is_force" ]; then
    printf 'error: --no-backup requires --force\n' >&2
    exit 1
  fi
  [ -n "$filter" ] || filter='.*'
}

# ------------------------------------------------------------- files ---

# `arr+=(...)` in a `while read` loop only works with process substitution --
# a pipe would run the loop in a subshell and silently discard the array.
# `|| [ -n "$line" ]` catches a final line with no trailing newline.
#
# The sed strips whole-line comments only; `s/#.*//' would corrupt any path
# containing a '#'. [[:space:]] is honoured by both BSD and GNU sed, unlike \s.
read_ignores() {
  ignores=()
  [ -f "$IGNORE_FILE" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    ignores+=("$line")
  done < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$IGNORE_FILE")
}

# emits "<root>\t<relpath>" for every linkable file under $1
list_root() {
  [ -d "$1" ] || return 0
  # Pure bash/POSIX lister, no node. Ignore set ($IGN_TMP, built once in
  # collect()): exact relpath, or any path under a directory entry. Files of
  # unknown type (fifo/socket) never reach here -- `find -type f` skips them
  # silently, where list-files.mjs used to error and exit 1. Deliberate.
  find "$1" -type f 2>/dev/null \
    | awk -v r="$1" '
        NR == FNR { ign[$0] = 1; next }
        { rel = substr($0, length(r) + 2)
          if (rel ~ /^!/) next
          for (i in ign)
            if (rel == i || index(rel, i "/") == 1) { skip = 1; break }
          if (!skip) print rel
          skip = 0 }' "$IGN_TMP" - \
    | sort \
    | awk -v r="$1" 'BEGIN { OFS = "\t" } { print r, $0 }'
  find "$1" -type l 2>/dev/null | while IFS= read -r l; do printf 'skip symlink: %s\n' "${l#$1/}" >&2; done
}

collect() {
  merged="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  desired="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  mdirs="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  IGN_TMP="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  trap 'rm -f "$merged" "$desired" "$mdirs" "$IGN_TMP" "$CTX_TMP" "$menu" "$PICKED_LINKS" "$merged.tmp"' EXIT INT TERM HUP

  # Ignore set, built once for all list_root calls: strip any leading ./ and
  # trailing / so entries compare cleanly against the lister's relpaths.
  printf '%s\n' "${ignores[@]}" | sed 's#^\./##; s#/$##' > "$IGN_TMP"

  # OS root first, common second; awk keeps the FIRST hit per relpath, which
  # is exactly the overlay-wins rule. The filter is applied to the relative
  # path only -- matching the whole line would also match the absolute root.
  # Doing it in awk also avoids `set -e` tripping on grep's empty-result exit 1.
  # --refresh (and --audit) keep the overlay set complete instead of applying
  # the pattern here: the pattern narrows their candidates later, but their
  # linked-dir discovery and in-repo exclusion need every repo relpath.
  all_flag=0
  [ -n "$is_refresh" ] && all_flag=1
  [ -n "$is_audit" ] && all_flag=1
  { list_root "$OSDIR"; list_root "$COMMON"; } \
    | awk -F'\t' -v pat="$filter" -v all="$all_flag" \
        '!seen[$2]++ && (all == 1 || $2 ~ pat)' > "$merged"

  awk -F'\t' -v h="$HOME" '{ print h "/" $2 }' "$merged" | sort -u > "$desired"

  # Directories to scan for stale links. Derived from *every* root, not just
  # the active one, so that switching a $HOME between Linux and macOS -- or
  # moving a file from common/ into an overlay -- prunes the links that the
  # other platform left behind (e.g. ~/bin/arch-scripts/* on macOS).
  { list_root "$COMMON"; list_root "$REPO/linux"; list_root "$REPO/macos"; } \
    | awk -F'\t' -v h="$HOME" \
        '{ p = h "/" $2; sub(/\/[^\/]*$/, "", p); print p }' \
    | sort -u > "$mdirs"
}

# ------------------------------------------------------------ picker ---

# Menu lines are "rel \t [<group>] rel"; the group label drives the fallback
# menu's section headers. fzf >= 0.48 knows the start event, so there we can
# preselect everything on open; older fzf starts empty (ctrl-a still works).
fzf_ge() {
  local v vma vmi ma mi
  v="$(fzf --version 2>/dev/null | awk '{print $1}')"
  IFS=. read -r vma vmi _ < <(printf '%s\n' "${v:-0}")
  IFS=. read -r ma mi _ < <(printf '%s\n' "$1")
  if [ "${vma:-0}" -gt "${ma:-0}" ] || { [ "${vma:-0}" -eq "${ma:-0}" ] && [ "${vmi:-0}" -ge "${mi:-0}" ]; }; then
    return 0
  else
    return 1
  fi
}

picker_bind() {
  if fzf_ge 0.48; then
    printf '%s' 'ctrl-a:select-all,ctrl-d:deselect-all,start:select-all'
  else
    printf '%s' 'ctrl-a:select-all,ctrl-d:deselect-all'
  fi
}

# Pure-bash multi-select when fzf can't be used (not installed, or stdin is
# not a terminal). Menu entries come from $1; the selection is read from the
# real stdin (a tty, or a pipe in headless runs). stdout is the result.
menu_fallback() {
  local keys labels k l n=0 i sel tok lo hi last_group group menu_file
  keys=(); labels=()
  menu_file="$1"
  while IFS=$'\t' read -r k l || [ -n "$k" ]; do
    keys[$n]="$k"; labels[$n]="$l"; n=$((n + 1))
  done < "$menu_file"

  {
    last_group=''
    i=0
    while [ $i -lt $n ]; do
      group="${labels[$i]#[}"
      group="${group%%]*}"
      if [ "$group" != "$last_group" ]; then
        printf '\n  ---- %s ----\n' "$group"
        last_group="$group"
      fi
      printf '%4d) %s\n' "$((i + 1))" "${labels[$i]}"
      i=$((i + 1))
    done
    printf '\n(fzf not available -- using the basic picker)\n'
    printf "Select: 'a' = all (default) · 'n' = none · numbers and ranges · empty = all\n> "
  } 2>/dev/null >/dev/tty || true

  if [ -t 0 ]; then
    read -r sel </dev/tty || sel=''
  else
    read -r sel || sel=''
  fi

  for i in $(expand_selection "$n" "$sel"); do
    printf '%s\n' "${keys[$((i - 1))]}"
  done
}

# expand_selection <count> <input> -> the selected 1-based indices, one per line
# Accepts numbers, "lo-hi" ranges, "a"/"all" or empty = everything, "n" = none.
expand_selection() {
  local n="$1" sel="$2" tok lo hi i

  case "$sel" in
    n|N|none) return ;;
    a|A|all|'')
      i=1; while [ "$i" -le "$n" ]; do printf '%s\n' "$i"; i=$((i + 1)); done
      return ;;
  esac

  for tok in $sel; do
    case "$tok" in
      *-*) lo="${tok%%-*}"; hi="${tok##*-}" ;;
      *)   lo="$tok";       hi="$tok" ;;
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

picker() {
  # Menu: rel \t [<group>] rel, grouped for the numbered fallback.
  menu="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  PICKED_LINKS="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"

  awk -F'\t' '
    { rel = $2
      if (rel ~ /^\.config\/[^/]+\//) { split(rel, a, "/"); g = a[2] }
      else if (rel ~ /^bin\//) g = "bin"
      else if (rel == ".tmux.conf") g = "tmux"
      else if (rel == ".gitconfig" || rel == ".gitignore_global" || rel ~ /^\.config\/git\//) g = "git"
      else if (rel == ".bashrc" || rel == ".bash_profile" || rel == ".zshrc" || rel == ".profile" || rel == ".hushlogin" || rel ~ /^\.config\/shell\//) g = "shell"
      else if (rel == ".Xmodmap" || rel == ".xinitrc") g = "x11"
      else g = "other"
      printf "%s\t[%s] %s\n", rel, g, rel
    }' "$merged" > "$menu"

  # tty decides fzf-vs-fallback INSIDE the picker; piped stdin, cron/CI and
  # fzf-less machines all take the numbered menu.
  if [ -t 0 ] && command -v fzf >/dev/null 2>&1; then
    fzf --multi --delimiter=$'\t' --with-nth=2.. --height=90% --reverse \
        --tiebreak=index --prompt='link> ' \
        --header='TAB toggle · CTRL-A select all matches · CTRL-D deselect all · ENTER link' \
        --bind "$(picker_bind)" < "$menu" | cut -f1 > "$PICKED_LINKS"
  else
    menu_fallback "$menu" > "$PICKED_LINKS"
  fi

  if [ ! -s "$PICKED_LINKS" ]; then
    echo 'Nothing selected.'
    exit 0
  fi

  # Narrow $merged to the picked relpaths; the rest of the pipeline (classify,
  # find_stale, confirm, apply) runs on the choice alone.
  awk -F'\t' 'NR==FNR { p[$0] = 1; next } $2 in p' "$PICKED_LINKS" "$merged" \
    > "$merged.tmp" && mv "$merged.tmp" "$merged"

  # Rebuild $mdirs from the parents of the picked relpaths, so stale-link
  # removal stays inside the choice. Top-level files map to $HOME itself,
  # matching the formula used in collect().
  awk -v h="$HOME" '{ p = h "/" $0; sub(/\/[^\/]*$/, "", p); print p }' \
    "$PICKED_LINKS" | sort -u > "$mdirs"
}

# ---------------------------------------------------------- classify ---

# Parallel arrays instead of a hash: bash 3.2 has no associative arrays.
n_same=0
new_rel=();  new_src=()
soft_rel=(); soft_src=(); soft_why=()   # resolvable without --force
hard_rel=(); hard_src=(); hard_why=()   # needs --force
stale=()

classify() {
  local root rel src dst cur
  while IFS=$'\t' read -r root rel || [ -n "$rel" ]; do
    src="$root/$rel"
    dst="$HOME/$rel"

    # -L before -e: a symlink to a nonexistent path fails -e but is still a link
    if [ -L "$dst" ]; then
      cur="$(readlink "$dst")"
      if [ "$cur" = "$src" ]; then
        n_same=$((n_same + 1))
        continue
      fi
      case "$cur" in
        "$REPO"/*)
          soft_rel+=("$rel"); soft_src+=("$src")
          soft_why+=("relink, was -> ${cur#$REPO/}") ;;
        *)
          hard_rel+=("$rel"); hard_src+=("$src")
          hard_why+=("foreign link -> $cur") ;;
      esac
    elif [ -e "$dst" ]; then
      if [ "$dst" -ef "$src" ]; then
        # same inode: this is an old hard link from the pre-symlink scheme.
        # Byte-identical by definition, so converting risks nothing.
        soft_rel+=("$rel"); soft_src+=("$src")
        soft_why+=("hard link -> symlink")
      else
        hard_rel+=("$rel"); hard_src+=("$src")
        hard_why+=("existing file, will be backed up")
      fi
    else
      new_rel+=("$rel"); new_src+=("$src")
    fi
  done < "$merged"
}

# Symlinks in a managed directory that point into this repo but are no longer
# wanted (source deleted, or moved between overlays leaving a broken link).
# Only ever touches links whose target is under $REPO, so unrelated symlinks
# in $HOME are never at risk.
find_stale() {
  local d l t rel
  while IFS= read -r d || [ -n "$d" ]; do
    [ -d "$d" ] || continue
    while IFS= read -r l || [ -n "$l" ]; do
      t="$(readlink "$l")"
      case "$t" in "$REPO"/*) ;; *) continue ;; esac
      # `grep ... && continue` would abort the script under `set -e`
      if grep -Fxq "$l" "$desired"; then continue; fi
      rel="${l#$HOME/}"
      # RHS of =~ must stay unquoted: bash 3.2 matches a quoted RHS literally
      [[ $rel =~ $filter ]] || continue
      stale+=("$l")
    done < <(find "$d" -maxdepth 1 -type l)
  done < "$mdirs"
}

# ---------------------------------------------------------- refresh ---

# --refresh: capture new real files that appeared inside linked dirs into the
# repo (mirror-root: OS overlay wins, else common) and symlink them back.
# One direction only (home -> repo); never touches existing repo files;
# conflicts and ignored paths are skipped, not resolved.
rfr_rel=(); rfr_home=(); rfr_dest=(); rfr_root=()

refresh_scan() {
  local d rel f ddir dest root

  # Linked dirs = unique dirnames of merged rels that contain a `/`. Top-level
  # rels (parent is $HOME itself) are skipped -- $HOME is never scanned. Nested
  # dirs collapse to their shallowest ancestor so `find` never reports a file
  # twice (e.g. .config/nvim and .config/nvim/lua/plugins).
  # `$desired` (built in collect) doubles as the in-repo rel set: a candidate
  # whose absolute path is listed there is already managed (or a conflict) and
  # is skipped silently, exactly like find_stale (:368).
  while IFS= read -r d || [ -n "$d" ]; do
    [ -d "$HOME/$d" ] || continue
    [ -L "$HOME/$d" ] && continue
    # find -type f skips symlinks and never descends into symlinked subdirs
    while IFS= read -r f || [ -n "$f" ]; do
      rel="${f#$HOME/}"
      # already in the repo (managed or conflict) -> skip silently
      if grep -Fxq "$f" "$desired"; then continue; fi
      # link-ignore.txt, exact or under a directory entry (list_root:130-137)
      if awk -v rel="$rel" \
          'rel == $0 || index(rel, $0 "/") == 1 { found = 1 } END { exit !found }' \
          "$IGN_TMP"; then continue; fi
      # gitignored; a git error (no repo) also skips -- never capture a file
      # we cannot prove is not ignored (git check-ignore --no-index works
      # without the index but still needs a repository)
      if git -C "$REPO" check-ignore --no-index -q -- "$rel" 2>/dev/null; then
        continue
      elif [ $? -ne 1 ]; then
        continue
      fi
      case "$rel" in
        */.git/*|.git/*) continue ;;
        *.bak.*)         continue ;;
      esac
      # `=~` RHS must stay unquoted for bash 3.2 (find_stale:371)
      [[ $rel =~ $filter ]] || continue
      # mirror-root rule: OS overlay if the dir exists there, else common
      ddir="$(dirname "$rel")"
      if [ -d "$OSDIR/$ddir" ]; then
        dest="$OSDIR/$rel"; root="$OS"
      else
        dest="$COMMON/$rel"; root=common
      fi
      rfr_rel+=("$rel"); rfr_home+=("$f"); rfr_dest+=("$dest"); rfr_root+=("$root")
    done < <(find "$HOME/$d" -type f 2>/dev/null)
  done < <(
    awk -F'\t' '{ r = $2; sub(/\/[^\/]*$/, "", r); if (r != $2) print r }' "$merged" \
      | sort -u \
      | awk '{ if ($0 != prev && index($0, prev "/") != 1) { print; prev = $0 } }'
  )
}

refresh_confirm() {
  local i

  if [ "${#rfr_rel[@]}" -eq 0 ]; then
    printf 'Nothing to refresh.\n'
    exit 0
  fi

  for ((i = 0; i < ${#rfr_rel[@]}; i++)); do
    printf -- '+  %s [refresh] -> %s\n' "${rfr_rel[$i]}" "${rfr_root[$i]}"
  done
  echo
  printf '   refresh: move %d new file(s) into %s/%s and symlink them back\n' \
    "${#rfr_rel[@]}" "${COMMON#$REPO/}" "${OSDIR#$REPO/}"
  echo

  [ -n "$is_dry" ] && exit 0
  [ -n "$is_yes" ] && return 0

  read -r -p "🔥 Are you sure? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) exit 1 ;;
  esac
}

refresh_apply() {
  local i

  for ((i = 0; i < ${#rfr_rel[@]}; i++)); do
    printf -- '-> mv + ln -s %s\n' "${rfr_rel[$i]}"
    mkdir -p "$(dirname "${rfr_dest[$i]}")"
    mv "${rfr_home[$i]}" "${rfr_dest[$i]}"
    # Rollback: a user file must never be left only in the repo.
    if ! ln -s "${rfr_dest[$i]}" "${rfr_home[$i]}"; then
      mv "${rfr_dest[$i]}" "${rfr_home[$i]}"
      printf 'error: ln failed for %s; file moved back to %s\n' \
        "${rfr_rel[$i]}" "${rfr_home[$i]}" >&2
      exit 1
    fi
  done
}

# ------------------------------------------------------------- audit ---

# --audit: read-only link-drift report. Direction (a) = repo files lacking a
# correct home link (classify/find_stale); direction (b) = real files inside
# linked dirs absent from the repo (refresh_scan's candidates, not applied).
# Lines whose rel is neglected for the current session context are dropped;
# nothing is written, no picker, no prompt. Exit 0 = clean, 1 = findings.

# Session context for the neglect list. Order matters: Xwayland sets DISPLAY
# too, so WAYLAND_DISPLAY is checked first.
session_context() {
  if [ -n "$WAYLAND_DISPLAY" ]; then
    printf 'wayland\n'
  elif [ -n "$DISPLAY" ]; then
    printf 'x11\n'
  else
    printf 'headless\n'
  fi
}

# Mirror read_ignores (:114-120): whole-line comments and blank lines dropped,
# lines without a "<context>: " pair are malformed and ignored. A missing
# link-context.txt is an empty neglect list, not an error.
read_contexts() {
  CTX_TMP="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  [ -f "$CTX_FILE" ] || return 0
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' -e '/: /!d' "$CTX_FILE" \
    > "$CTX_TMP" 2>/dev/null || :
}

# relpath R is neglected iff the context file lists it for a context other
# than the current session's (>=1 line "<ctx>: R" exists AND session_context()
# is not among those <ctx> values). Unlisted R is never neglected.
neglected() {
  local rel="$1" sctx line ctx r found=0 current=0
  [ -f "$CTX_TMP" ] || return 1
  sctx="$(session_context)"
  while IFS= read -r line || [ -n "$line" ]; do
    ctx="${line%%: *}"
    r="${line#*: }"
    [ "$r" = "$rel" ] || continue
    found=1
    [ "$ctx" = "$sctx" ] && current=1
  done < "$CTX_TMP"
  [ "$found" = 1 ] && [ "$current" = 0 ]
}

audit() {
  local sctx i rel line ctx neglects=() neglect_str='' findings=0 suppressed=0
  sctx="$(session_context)"

  # header neglect list: context-file lines naming a session other than ours
  while IFS= read -r line || [ -n "$line" ]; do
    ctx="${line%%: *}"
    [ "$ctx" = "$sctx" ] || neglects+=("$line")
  done < "$CTX_TMP"
  for line in "${neglects[@]}"; do
    [ -n "$neglect_str" ] && neglect_str="$neglect_str, "
    neglect_str="$neglect_str$line"
  done
  if [ -n "$neglect_str" ]; then
    printf 'audit context: %s (neglecting: %s)\n' "$sctx" "$neglect_str"
  else
    printf 'audit context: %s\n' "$sctx"
  fi

  # direction (a): stale links, then repo files missing/relink/conflict
  for ((i = 0; i < ${#stale[@]}; i++)); do
    rel="${stale[$i]#$HOME/}"
    if neglected "$rel"; then suppressed=$((suppressed + 1)); continue; fi
    [[ $rel =~ $filter ]] || continue
    printf -- '-  %-44s %s\n' "$rel" 'stale link'
    findings=$((findings + 1))
  done
  for ((i = 0; i < ${#new_rel[@]}; i++)); do
    rel="${new_rel[$i]}"
    if neglected "$rel"; then suppressed=$((suppressed + 1)); continue; fi
    [[ $rel =~ $filter ]] || continue
    printf -- '+  %-44s %s\n' "$rel" '[missing]'
    findings=$((findings + 1))
  done
  for ((i = 0; i < ${#soft_rel[@]}; i++)); do
    rel="${soft_rel[$i]}"
    if neglected "$rel"; then suppressed=$((suppressed + 1)); continue; fi
    [[ $rel =~ $filter ]] || continue
    printf -- '*  %-44s %s\n' "$rel" '[relink]'
    findings=$((findings + 1))
  done
  for ((i = 0; i < ${#hard_rel[@]}; i++)); do
    rel="${hard_rel[$i]}"
    if neglected "$rel"; then suppressed=$((suppressed + 1)); continue; fi
    [[ $rel =~ $filter ]] || continue
    printf -- '!  %-44s %s\n' "$rel" '[conflict]'
    findings=$((findings + 1))
  done
  # direction (b): refresh_scan's unlinked candidates (already filtered by
  # the pattern inside refresh_scan, so no `=~` re-check here)
  for ((i = 0; i < ${#rfr_rel[@]}; i++)); do
    rel="${rfr_rel[$i]}"
    if neglected "$rel"; then suppressed=$((suppressed + 1)); continue; fi
    printf -- '+  %-44s %s\n' "$rel" '[unlinked]'
    findings=$((findings + 1))
  done

  if [ "$findings" -eq 0 ]; then
    printf 'Audit clean (%d links correct, %d neglected).\n' "$n_same" "$suppressed"
    exit 0
  fi
  printf 'Audit findings: %d.\n' "$findings"
  exit 1
}

# ----------------------------------------------------------- preview ---

tag_of() { # $1 = absolute src -> [common] / [linux] / [macos]
  case "$1" in
    "$COMMON"/*) printf '[common]' ;;
    "$OSDIR"/*)  printf '[%s]' "$OS" ;;
    *)           printf '[?]' ;;
  esac
}

preview() {
  local i

  for ((i = 0; i < ${#stale[@]}; i++)); do
    printf -- '-  %-44s %s\n' "${stale[$i]#$HOME/}" 'stale link'
  done
  for ((i = 0; i < ${#new_rel[@]}; i++)); do
    printf -- '+  %-44s %s\n' "${new_rel[$i]}" "$(tag_of "${new_src[$i]}")"
  done
  for ((i = 0; i < ${#soft_rel[@]}; i++)); do
    printf -- '*  %-44s %s %s\n' "${soft_rel[$i]}" "$(tag_of "${soft_src[$i]}")" "${soft_why[$i]}"
  done
  for ((i = 0; i < ${#hard_rel[@]}; i++)); do
    printf -- '%s  %-44s %s %s\n' \
      "$([ -n "$is_force" ] && echo '~' || echo '!')" \
      "${hard_rel[$i]}" "$(tag_of "${hard_src[$i]}")" "${hard_why[$i]}"
  done
}

confirm() {
  local actionable
  actionable=$(( ${#stale[@]} + ${#new_rel[@]} + ${#soft_rel[@]} ))
  [ -n "$is_force" ] && actionable=$(( actionable + ${#hard_rel[@]} ))

  if [ "$actionable" -eq 0 ]; then
    if [ ${#hard_rel[@]} -gt 0 ]; then
      preview
      echo
      printf 'Nothing to do (%d links already correct); ' "$n_same"
      printf 'use --force to resolve %d conflict(s).\n' "${#hard_rel[@]}"
      exit 0
    fi
    printf 'Nothing to do (%d links already correct).\n' "$n_same"
    exit 0
  fi

  preview
  echo
  printf '   %s + %s  ->  %s\n' "${COMMON#$REPO/}" "${OSDIR#$REPO/}" "$HOME"
  [ "$n_same" -gt 0 ] && printf '   (%d link(s) already correct)\n' "$n_same"
  if [ -z "$is_force" ] && [ ${#hard_rel[@]} -gt 0 ]; then
    printf '   %d conflict(s) skipped -- re-run with --force\n' "${#hard_rel[@]}"
  fi
  echo

  [ -n "$is_dry" ] && exit 0
  [ -n "$is_yes" ] && return 0

  read -r -p "🔥 Are you sure? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) exit 1 ;;
  esac
}

# ------------------------------------------------------------- apply ---

# Now that we create symlinks, a pre-existing link like ~/.config/nvim ->
# <repo>/common/.config/nvim would make mkdir -p + ln write self-referential
# links back into the repo. Refuse instead.
in_repo_guard() {
  local d
  d="$(cd -P "$1" >/dev/null 2>&1 && pwd)" || return 0
  case "$d/" in
    "$REPO"/*)
      printf 'refusing: %s resolves inside the repo (%s)\n' "$1" "$d" >&2
      exit 1 ;;
  esac
}

link_one() { # $1=src $2=dst $3=1 to back up an existing real file
  local d
  d="$(dirname "$2")"
  if [ -d "$d" ]; then in_repo_guard "$d"; fi
  mkdir -p "$d"
  if [ "$3" = 1 ] && [ -e "$2" ] && [ ! -L "$2" ]; then
    # --no-backup deletes the real file instead of moving it aside. A
    # directory cannot be rm -f'd (rm fails and set -e aborts mid-apply), so
    # refuse before touching anything. Plain --force keeps the backup mv.
    if [ -n "$is_no_backup" ] && [ -d "$2" ]; then
      printf 'error: --no-backup cannot replace a directory (%s); run --force without --no-backup or remove it manually\n' "$2" >&2
      exit 1
    fi
    if [ -n "$is_no_backup" ]; then
      printf -- '-> rm (no backup) %s\n' "$2"
      rm -f "$2"
    else
      printf -- '   backup %s -> %s\n' "$2" "$2.bak.$STAMP"
      mv "$2" "$2.bak.$STAMP"
    fi
  fi
  # rm + ln, never `ln -sf`: on BSD, forcing a link over an existing symlink
  # to a directory creates the link *inside* it, and the flag that prevents
  # that differs between BSD (-h) and GNU (-n/-T). Removing first sidesteps it.
  rm -f "$2"
  ln -s "$1" "$2"
}

apply() {
  local i

  for ((i = 0; i < ${#stale[@]}; i++)); do
    printf -- '-> rm %s\n' "${stale[$i]}"
    rm -f "${stale[$i]}"
  done
  for ((i = 0; i < ${#new_rel[@]}; i++)); do
    printf -- '-> ln -s %s\n' "${new_rel[$i]}"
    link_one "${new_src[$i]}" "$HOME/${new_rel[$i]}" 0
  done
  for ((i = 0; i < ${#soft_rel[@]}; i++)); do
    printf -- '-> ln -s %s\n' "${soft_rel[$i]}"
    link_one "${soft_src[$i]}" "$HOME/${soft_rel[$i]}" 0
  done
  if [ -n "$is_force" ]; then
    for ((i = 0; i < ${#hard_rel[@]}; i++)); do
      printf -- '-> ln -s %s\n' "${hard_rel[$i]}"
      link_one "${hard_src[$i]}" "$HOME/${hard_rel[$i]}" 1
    done
  fi
}

# -------------------------------------------------------------- main ---

parse_args "$@"
read_ignores
collect
# The picker chooses which repo files to link out; capture/report modes
# (--refresh, --audit) never open it.
if [ -z "$is_dry" ] && [ -z "$is_yes" ] && [ -z "$pattern_given" ] \
  && [ -z "$is_refresh" ] && [ -z "$is_audit" ]; then
  picker
fi
if [ -n "$is_refresh" ]; then
  refresh_scan
  refresh_confirm
  refresh_apply
  exit 0
fi
classify
find_stale
if [ -n "$is_audit" ]; then
  read_contexts
  refresh_scan
  audit
  exit 0
fi
confirm
apply
