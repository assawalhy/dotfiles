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
#   NIXOS_DIR     destination directory (default: /etc/nixos)
#   SUDO_ASKPASS  helper `sudo -A` runs for the password. When there is no TTY
#                 and we are not root, the script elevates with `sudo -A`
#                 automatically, defaulting SUDO_ASKPASS to sudo-askpass or
#                 ssh-askpass on PATH, else a Zenity wrapper.
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
  NIXOS_DIR     destination directory (default: /etc/nixos)
  SUDO_ASKPASS  askpass helper for `sudo -A` (used when there is no TTY)

When run without a TTY and not as root, the script elevates with `sudo -A`
so it never hangs waiting for a password on a terminal that is not there.

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

# Elevation. With a TTY, plain sudo prompts there. Without one (agents, CI,
# cron) sudo cannot prompt, so use -A and an askpass helper. As root, no sudo.
if [ "$(id -u)" -eq 0 ]; then
  SUDO=()
elif [ -t 0 ]; then
  SUDO=(sudo)
else
  SUDO=(sudo -A)
  if [ -z "${SUDO_ASKPASS:-}" ]; then
    if command -v zenity >/dev/null 2>&1; then
      askpass="$(mktemp -t update-nixos-askpass.XXXXXX)"
      printf '#!/bin/sh\nexec zenity --password --title "sudo passwd to update nix"\n' >"$askpass"
      chmod 700 "$askpass"
      export SUDO_ASKPASS="$askpass"
      trap 'rm -f "$askpass"' EXIT
    else
      echo "update-nixos: no TTY and no askpass helper; run in a terminal or set SUDO_ASKPASS." >&2
      exit 1
    fi
  fi
fi

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
  "${SUDO[@]}" cp -a "$DEST/configuration.nix" "$DEST/configuration.nix.bak-$ts"
  echo "update-nixos: backed up configuration.nix -> configuration.nix.bak-$ts"
fi

if command -v rsync >/dev/null 2>&1; then
  "${SUDO[@]}" rsync -a --delete -i "${excludes[@]}" "$SRC/" "$DEST/"
else
  "${SUDO[@]}" cp -a "$SRC/." "$DEST/"
fi

echo "update-nixos: running nixos-rebuild $action"
if [ "${#rebuild_args[@]}" -gt 0 ]; then
  exec "${SUDO[@]}" nixos-rebuild "$action" "${rebuild_args[@]}"
else
  exec "${SUDO[@]}" nixos-rebuild "$action"
fi
