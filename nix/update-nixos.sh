#!/usr/bin/env bash
# update-nixos.sh — sync this repo's NixOS tree (nix/) to /etc/nixos and rebuild.
#
# The repo is the source of truth: nix/ is mirrored onto /etc/nixos, which
# nixos-rebuild then evaluates. Machine-specific files are never touched.
#
# Usage:
#   nix/update-nixos.sh [ACTION] [nixos-rebuild args...]
#
#   ACTION   nixos-rebuild action: switch (default), boot, test, build,
#            dry-build or dry-activate.
#   -n       show which files would sync; write nothing.
#   -h       this help.
#
# Environment:
#   NIXOS_DIR   destination directory (default: /etc/nixos)
#
# The mirror is `rsync -a --delete`. Excluded from both sync and delete:
#   - hardware-configuration.nix  (machine-specific, lives only in /etc/nixos)
#   - this script                 (a repo tool, not system config)
#   - configuration.nix.*         (timestamped backups made below)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/nix"
DEST="${NIXOS_DIR:-/etc/nixos}"
SELF="$(basename "${BASH_SOURCE[0]}")"

usage() {
  cat <<'EOF'
update-nixos.sh — sync this repo's NixOS tree (nix/) to /etc/nixos and rebuild.

Usage:
  nix/update-nixos.sh [ACTION] [nixos-rebuild args...]

  ACTION   nixos-rebuild action: switch (default), boot, test, build,
           dry-build or dry-activate.
  -n       show which files would sync; write nothing.
  -h       this help.

Environment:
  NIXOS_DIR   destination directory (default: /etc/nixos)

The repo is the source of truth: nix/ is mirrored onto /etc/nixos with
rsync --delete, so configs removed here disappear there. Never touched:
hardware-configuration.nix (machine-specific), this script, and backups.
EOF
}

dry=0
action=""
rebuild_args=()
for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
    -n | --dry-run)
      dry=1
      ;;
    -*)
      rebuild_args+=("$arg")
      ;;
    *)
      if [ -z "$action" ]; then
        action="$arg"
      else
        rebuild_args+=("$arg")
      fi
      ;;
  esac
done
action="${action:-switch}"

case "$action" in
  switch | boot | test | build | dry-build | dry-activate) ;;
  *)
    echo "update-nixos: unknown action '$action' (see -h)" >&2
    exit 2
    ;;
esac

[ -d "$SRC" ] || {
  echo "update-nixos: missing source directory $SRC" >&2
  exit 1
}

# Never overwrite or delete these in the destination.
excludes=(
  --exclude "hardware-configuration.nix"
  --exclude "$SELF"
  --exclude "configuration.nix.*"
)

echo "update-nixos: $SRC/ -> $DEST/   (rsync --delete, machine files preserved)"

if ! command -v rsync >/dev/null 2>&1; then
  echo "update-nixos: rsync not found, using 'cp -a' (no --delete)." >&2
  echo "              add pkgs.rsync to configuration.nix for the full mirror." >&2
fi

if [ "$dry" = 1 ]; then
  if command -v rsync >/dev/null 2>&1; then
    rsync -n -a --delete -i "${excludes[@]}" "$SRC/" "$DEST/"
  else
    echo "update-nixos: dry run needs rsync" >&2
    exit 1
  fi
  echo "update-nixos: dry run — nothing written."
  exit 0
fi

if [ ! -f "$DEST/hardware-configuration.nix" ]; then
  echo "update-nixos: $DEST/hardware-configuration.nix is missing;" >&2
  echo "              generate it with 'nixos-generate-config' first." >&2
  exit 1
fi

# Keep a timestamped copy of the live config before replacing it.
if [ -f "$DEST/configuration.nix" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  sudo cp -a "$DEST/configuration.nix" "$DEST/configuration.nix.bak-$ts"
  echo "update-nixos: backed up configuration.nix -> configuration.nix.bak-$ts"
fi

if command -v rsync >/dev/null 2>&1; then
  sudo rsync -a --delete -i "${excludes[@]}" "$SRC/" "$DEST/"
else
  sudo cp -a "$SRC/." "$DEST/"
fi

echo "update-nixos: running nixos-rebuild $action"
if [ "${#rebuild_args[@]}" -gt 0 ]; then
  exec sudo nixos-rebuild "$action" "${rebuild_args[@]}"
else
  exec sudo nixos-rebuild "$action"
fi
