#!/usr/bin/env bash
#
# link-files.bash -- symlink this repo's dotfiles into $HOME (macOS + Linux).
#
# Sources are  <repo>/common  and  <repo>/<os>  where <os> is linux or macos.
# On a path collision the OS overlay wins. The repo is the source of truth;
# there is no capture-from-$HOME direction (see --reverse below).
#
# NOTE: must stay bash 3.2 compatible -- stock macOS /bin/bash is 3.2.57.
#       No readarray/mapfile, no `declare -A`, no ${v,,}, no globstar.

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
LISTER="$REPO/list-files.mjs"
STAMP="$(date +%Y%m%d%H%M%S)"

# --------------------------------------------------------------- cli ---

is_help=; is_force=; is_dry=; is_yes=; filter=

print_help() {
cat <<EOF
USAGE:
  $(basename "$0") [--help] [--force] [--dry-run] [--yes] [filtering_pattern]
  $(basename "$0") --force '.*nvim/lua.*'

Symlinks $COMMON and $OSDIR into \$HOME.
Detected OS: $OS

OPTIONS:
  -h, --help      show this message and exit
      --force     resolve conflicts: replace foreign symlinks, and back up
                  real files to <file>.bak.<timestamp> before linking
  -n, --dry-run   show what would happen, then exit without changing anything
  -y, --yes       skip the confirmation prompt
  <pattern>       extended regex; only paths matching it are considered

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
        filter="$o" ;;
    esac
  done

  if [ -n "$is_help" ]; then print_help; exit 0; fi
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
  # ${ignores[@]/#/!} prefixes each element with '!' (the lister's ignore
  # marker) and correctly expands to zero args when the array is empty.
  node "$LISTER" "$1" . ${ignores[@]+"${ignores[@]/#/!}"} \
    | awk -v r="$1" 'BEGIN { OFS = "\t" } { print r, $0 }'
}

collect() {
  merged="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  desired="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  mdirs="$(mktemp "${TMPDIR:-/tmp}/link-files.XXXXXX")"
  trap 'rm -f "$merged" "$desired" "$mdirs"' EXIT INT TERM HUP

  # OS root first, common second; awk keeps the FIRST hit per relpath, which
  # is exactly the overlay-wins rule. The filter is applied to the relative
  # path only -- matching the whole line would also match the absolute root.
  # Doing it in awk also avoids `set -e` tripping on grep's empty-result exit 1.
  { list_root "$OSDIR"; list_root "$COMMON"; } \
    | awk -F'\t' -v pat="$filter" '!seen[$2]++ && $2 ~ pat' > "$merged"

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
    printf -- '   backup %s -> %s\n' "$2" "$2.bak.$STAMP"
    mv "$2" "$2.bak.$STAMP"
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
classify
find_stale
confirm
apply
