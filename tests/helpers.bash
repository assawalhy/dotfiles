#!/usr/bin/env bash
#
# helpers.bash -- fixture + run helpers for the link-files.bash bats suite.
#
# Every test builds a throwaway fixture repo + fake $HOME under
# $BATS_TEST_TMPDIR (auto-cleaned by bats); the real $HOME is never touched.
# link-files.bash derives $REPO from its own location, so each test copies
# the real script into its own fixture repo -- hermetic runs.
#
# NOTE: these helpers run under the modern bash of the bats runner; the
# *script* under test must stay bash 3.2 compatible, and is never edited here.

SCRIPT="$BATS_TEST_DIRNAME/../link-files.bash"

# ------------------------------------------------------------------- OS ---

# Fakes `uname -s` for child bash processes (bash exports functions, and
# link-files.bash runs under bash). $FIX_OS is exported so the function body
# sees it in the child.
stub_uname() { # <Linux|Darwin>
  FIX_OS="$1"
  export FIX_OS
  uname() { [ "$1" = -s ] && printf '%s\n' "$FIX_OS"; }
  export -f uname
}

# ------------------------------------------------------------- fixtures ---

# fixture_new <name> [git]
#   Creates $BATS_TEST_TMPDIR/<name>/repo (a copy of link-files.bash plus a
#   minimal common/linux/macos tree, seeded link-ignore.txt and
#   link-context.txt with the real files as starting point, optionally
#   `git init`'d for --refresh/--audit tests) and <name>/home (the fake
#   $HOME). Sets FIX_REPO and FIX_HOME.
fixture_new() {
  local name="$1"
  FIX_DIR="$BATS_TEST_TMPDIR/$name"
  FIX_REPO="$FIX_DIR/repo"
  FIX_HOME="$FIX_DIR/home"
  mkdir -p "$FIX_REPO/common/.config/mpv" "$FIX_REPO/common/.config/nvim" \
           "$FIX_REPO/linux/.config/shell" "$FIX_REPO/macos/.config/shell" \
           "$FIX_HOME"
  cp "$SCRIPT" "$FIX_REPO/link-files.bash"
  printf 'zshrc\n'       > "$FIX_REPO/common/.zshrc"
  printf 'tmux\n'        > "$FIX_REPO/common/.tmux.conf"
  printf '#mpv\n'        > "$FIX_REPO/common/.config/mpv/mpv.conf"
  printf 'nvim init\n'   > "$FIX_REPO/common/.config/nvim/init.lua"
  printf 'xmodmap\n'     > "$FIX_REPO/linux/.Xmodmap"
  printf 'xinitrc\n'     > "$FIX_REPO/linux/.xinitrc"
  printf 'linux os\n'    > "$FIX_REPO/linux/.config/shell/os.sh"
  printf 'macos os\n'    > "$FIX_REPO/macos/.config/shell/os.sh"
  printf 'hushlogin\n'   > "$FIX_REPO/macos/.hushlogin"
  cp "$BATS_TEST_DIRNAME/../link-ignore.txt"  "$FIX_REPO/link-ignore.txt"
  cp "$BATS_TEST_DIRNAME/../link-context.txt" "$FIX_REPO/link-context.txt"
  if [ "$2" = git ]; then git -C "$FIX_REPO" init -q; fi
}

# mkhome_link <rel> <target> -- create a symlink in the fixture home
mkhome_link() {
  local rel="$1" tgt="$2"
  mkdir -p "$FIX_HOME/$(dirname "$rel")"
  ln -s "$tgt" "$FIX_HOME/$rel"
}

# ------------------------------------------------------------ run links ---

# run_link <args...> -- run the fixture script with a headless (no
# WAYLAND_DISPLAY/DISPLAY) fixture home. bats `run` executes in a subshell,
# so HOME and the env must be exported before the call.
run_link() {
  export HOME="$FIX_HOME"
  unset WAYLAND_DISPLAY DISPLAY
  run "$FIX_REPO/link-files.bash" "$@"
}

# run_link_sess <wayland|x11|headless> <args...> -- like run_link but with a
# chosen session context (link-context.txt neglect filtering depends on it).
run_link_sess() {
  export HOME="$FIX_HOME"
  case "$1" in
    wayland) export WAYLAND_DISPLAY=wayland-0; unset DISPLAY ;;
    x11)     export DISPLAY=:0; unset WAYLAND_DISPLAY ;;
    *)       unset WAYLAND_DISPLAY DISPLAY ;;
  esac
  shift
  run "$FIX_REPO/link-files.bash" "$@"
}

# run_link_stdin <stdin-text> <args...> -- run the fixture script with the
# given text piped to its stdin (stdin is not a tty, so the numbered fallback
# menu is used and the confirmation prompt reads the next line). Wrapped in
# `bash -c` because bats `run` cannot capture a pipeline directly.
run_link_stdin() {
  local input="$1"; shift
  export HOME="$FIX_HOME"
  unset WAYLAND_DISPLAY DISPLAY
  local cmd
  cmd="printf '%s' $(printf '%q' "$input") | $(printf '%q' "$FIX_REPO/link-files.bash")"
  local a
  for a in "$@"; do cmd="$cmd $(printf '%q' "$a")"; done
  run bash -c "$cmd"
}

# ----------------------------------------------------------- assertions ---

# assert_link <rel> <target> -- $FIX_HOME/<rel> is a symlink to <target>
assert_link() {
  local rel="$1" tgt="$2"
  [ -L "$FIX_HOME/$rel" ]
  [ "$(readlink "$FIX_HOME/$rel")" = "$tgt" ]
}

# assert_no_link <rel> -- $FIX_HOME/<rel> does not exist at all
assert_no_link() {
  [ ! -e "$FIX_HOME/$1" ]
}

# output_has_finding <rel> -- audit/preview-style finding line for <rel>
# ("+  rel ...", "-  rel ...", "*  rel ...", "!  rel ...") is present
output_has_finding() {
  grep -qE "^[+*!~-]  $1( |$)" <<< "$output"
}

# output_not_has_finding <rel> -- no finding line for <rel>
output_not_has_finding() {
  ! grep -qE "^[+*!~-]  $1( |$)" <<< "$output"
}
