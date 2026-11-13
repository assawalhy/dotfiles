#!/usr/bin/env bash
# Local development loop for Astra Monitor (nix/astra-monitor/package.nix).
#
# The working tree lives outside the dotfiles repo (default
# ~/Projects/astra-monitor): upstream at the rev package.nix pins, on a branch
# `local` that carries nix/astra-monitor/patches/ as commits. Edit there, test
# in a nested shell, then `export` the commits back into patches/ so the
# system build (nixos-rebuild) picks them up.
#
#   dev.sh init           clone upstream, branch `local`, git am the patches
#   dev.sh check          type-check the working tree (npm install on first use)
#   dev.sh build          nix-build the working tree -> $CACHE/result
#   dev.sh nested         build, then run it in a nested GNOME Shell window
#   dev.sh export         git format-patch `local` into nix/astra-monitor/patches/
#   dev.sh bench [secs]   A/B gnome-shell CPU time, extension enabled vs disabled
#   dev.sh log            follow this extension's lines in the shell journal
set -euo pipefail

HERE=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TREE=${ASTRA_DIR:-$HOME/Projects/astra-monitor}
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/astra-monitor-dev
UUID=monitor@astraext.github.io
UPSTREAM=https://github.com/AstraExt/astra-monitor.git

die() { echo "dev.sh: $*" >&2; exit 1; }

pinned_rev() {
  sed -n 's/^ *rev = "\([0-9a-f]\{40\}\)";/\1/p' "$HERE/package.nix" | head -n1
}

need_tree() {
  git -C "$TREE" rev-parse --git-dir >/dev/null 2>&1 \
    || die "no working tree at $TREE (run: dev.sh init, or set ASTRA_DIR)"
}

cmd_init() {
  local rev
  rev=$(pinned_rev)
  [ -n "$rev" ] || die "could not read the pinned rev from package.nix"
  if [ -e "$TREE" ]; then
    die "$TREE already exists; remove it or set ASTRA_DIR to another path"
  fi
  mkdir -p "$(dirname "$TREE")"
  git clone "$UPSTREAM" "$TREE"
  git -C "$TREE" switch -C local "$rev"
  shopt -s nullglob
  local patches=("$HERE"/patches/*.patch)
  if [ ${#patches[@]} -gt 0 ]; then
    git -C "$TREE" am --3way "${patches[@]}"
  fi
  echo "working tree ready: $TREE (branch local, base ${rev:0:7})"
}

cmd_check() {
  need_tree
  cd "$TREE"
  # @girs/* type packages: ~300 MB, only needed for the type check, so they
  # stay in the working tree and never reach the Nix build.
  [ -d node_modules ] || nix-shell -p nodejs --run 'npm install --no-audit --no-fund'
  # Upstream does not type-check cleanly against today's @girs releases
  # (~490 errors at the pinned rev, none in src/storage or src/utils), so only
  # the errors in files changed since the pinned rev count.
  local changed
  changed=$(git diff --name-only "$(pinned_rev)" -- '*.ts')
  [ -n "$changed" ] || { echo "no .ts changes since the pinned rev"; return; }
  nix-shell -p nodejs --run 'npx tsc --noEmit --pretty false -p .' 2>&1 \
    | grep -F "$changed" || echo "no type errors in: ${changed//$'\n'/ }"
}

cmd_build() {
  need_tree
  mkdir -p "$CACHE"
  nix-build -E "(import <nixpkgs> {}).callPackage $HERE/package.nix { localSrc = $TREE; }" \
    -o "$CACHE/result" >/dev/null
  echo "$CACHE/result/share/gnome-shell/extensions/$UUID"
}

cmd_nested() {
  local ext data mutter
  ext=$(cmd_build)
  # A throwaway XDG_DATA_HOME: the dev build shadows the system copy only in
  # the nested shell, never in the real session. (A copy in the real
  # ~/.local/share/gnome-shell/extensions would shadow the Nix one at every
  # login, the same trap epic 41 hit with copyous.)
  data=$(mktemp -d)
  trap 'rm -rf "$data"' EXIT
  mkdir -p "$data/gnome-shell/extensions"
  cp -r "$ext" "$data/gnome-shell/extensions/$UUID"
  chmod -R u+w "$data"
  # GNOME 49+ dropped --nested for --devkit, which execs mutter-devkit from PATH.
  mutter=$(nix-build --no-out-link '<nixpkgs>' -A mutter)
  echo "nested shell: dev build from $TREE (close the window to stop)"
  env XDG_DATA_HOME="$data" PATH="$mutter/libexec:$PATH" \
    MUTTER_DEBUG_DUMMY_MODE_SPECS=1600x900 SHELL_DEBUG=backtrace-warnings \
    dbus-run-session -- gnome-shell --devkit --wayland 2>&1 \
    | grep --line-buffered -iE 'astra|monitor@|JS ERROR|JS WARNING' || true
}

cmd_export() {
  need_tree
  local rev
  rev=$(pinned_rev)
  git -C "$TREE" merge-base --is-ancestor "$rev" HEAD \
    || die "HEAD in $TREE does not descend from the pinned rev ${rev:0:7}"
  # An empty range would wipe patches/ (e.g. after a failed `git am` in init).
  [ "$(git -C "$TREE" rev-list --count "$rev..HEAD")" -gt 0 ] \
    || die "no commits on top of ${rev:0:7} in $TREE; refusing to empty patches/"
  [ -z "$(git -C "$TREE" status --porcelain --untracked-files=no)" ] \
    || die "uncommitted changes in $TREE; commit them first"
  rm -f "$HERE"/patches/*.patch
  git -C "$TREE" format-patch --quiet --no-signature --zero-commit \
    -o "$HERE/patches" "$rev..HEAD"
  ls "$HERE/patches"
  echo "rebuild the system to use them: nix/update-nixos.sh"
}

shell_cpu_ticks() {
  # utime+stime of gnome-shell itself, plus cutime+cstime: the CPU of every
  # child it has reaped, which is where lsblk/nvidia-smi/ps spawns end up.
  local pid
  pid=$(pgrep -u "$USER" -x gnome-shell | head -n1)
  [ -n "$pid" ] || die "no gnome-shell process for $USER"
  awk '{ sub(/^.*\) /, ""); print $12 + $13, $14 + $15 }' "/proc/$pid/stat"
}

measure() {
  local secs=$1 a b
  read -r a ac < <(shell_cpu_ticks)
  sleep "$secs"
  read -r b bc < <(shell_cpu_ticks)
  local hz
  hz=$(getconf CLK_TCK)
  awk -v s="$((b - a))" -v c="$((bc - ac))" -v hz="$hz" -v t="$secs" \
    'BEGIN { printf "shell %5.2f%% CPU, children %5.2f%% CPU\n", 100*s/hz/t, 100*c/hz/t }'
}

cmd_bench() {
  local secs=${1:-60} key=/org/gnome/shell/enabled-extensions had_user_value
  gnome-extensions info "$UUID" >/dev/null || die "$UUID is not installed"
  # gnome-extensions writes enabled-extensions into the user dconf DB, which
  # then shadows the profile default in configuration.nix. Drop that write
  # again unless the user DB already held a value before the bench.
  had_user_value=$(dconf read "$key")
  echo "idle the desktop for $((secs * 2 + 10)) s; the menus must stay closed"
  gnome-extensions enable "$UUID"; sleep 5
  printf 'enabled:  '; measure "$secs"
  gnome-extensions disable "$UUID"; sleep 5
  printf 'disabled: '; measure "$secs"
  gnome-extensions enable "$UUID"
  [ -n "$had_user_value" ] || dconf reset "$key"
}

cmd_log() {
  journalctl --user -f -o cat /run/current-system/sw/bin/gnome-shell 2>/dev/null \
    | grep --line-buffered -iE 'astra|monitor@' \
    || journalctl -f -o cat _COMM=gnome-shell | grep --line-buffered -iE 'astra|monitor@'
}

case ${1:-} in
  init) cmd_init ;;
  check) cmd_check ;;
  build) cmd_build ;;
  nested) cmd_nested ;;
  export) cmd_export ;;
  bench) shift; cmd_bench "$@" ;;
  log) cmd_log ;;
  *) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; exit 1 ;;
esac
