#!/usr/bin/env bats
#
# link-known-issues.bats -- tests that ENCODE KNOWN BUGS as the desired
# (fixed) behavior. Each test currently FAILS and will turn green only when
# the underlying bug in link-files.bash is fixed. Keeping them in a separate
# file means the main suite (link-files.bats) stays green and each bug here
# is a standalone work item.
#
# Running: bats tests/link-known-issues.bats   (expected: all fail today)
#
# Loaded with the same helpers as the main suite; fixtures never touch the
# real $HOME.

load helpers

setup() {
  stub_uname Linux
}

# ---- known issue: --audit --refresh must never write -------------------
# parse_args only guards --fix; main checks is_refresh before is_audit, so
# --audit --refresh --yes silently moves a home file into the repo.
@test "known- audit combined with --refresh must not write (exclusivity)" {
  fixture_new ki_ar git
  git -C "$FIX_REPO" add -A
  git -C "$FIX_REPO" -c user.name=t -c user.email=t@t commit -qm init
  run_link --yes
  [ "$status" -eq 0 ]
  printf 'extra\n' > "$FIX_HOME/.config/mpv/extra.conf"
  run_link --audit --refresh --yes
  # audit is read-only: the home file must NOT be moved into the repo
  [ ! -e "$FIX_REPO/common/.config/mpv/extra.conf" ]
  [ -f "$FIX_HOME/.config/mpv/extra.conf" ]
  [ ! -L "$FIX_HOME/.config/mpv/extra.conf" ]
}

# ---- known issue: leading whitespace in link-context.txt breaks neglect --
# a "  x11: .Xmodmap" line parses ctx as "  x11" != "x11", so the file is
# neglected on every session, even its own x11 session.
@test "known- leading whitespace in link-context.txt is parsed (x11 keeps the file)" {
  fixture_new ki_ws
  printf '  x11: .Xmodmap\n' > "$FIX_REPO/link-context.txt"
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  run_link_sess x11 --audit
  [ "$status" -eq 1 ]
  [[ "$output" != *"neglecting:"* ]]
  [[ "$output" != *"x  .Xmodmap"* ]]
}

# ---- known issue: ignored+neglected link is double-reported -------------
# a link both in link-ignore.txt and neglected for the session is reported
# `i [ignored]` AND `x [neglected]`. Desired: report once, `i` wins (the
# ignore list is explicit config).
@test "known- ignored+neglected link is reported once, i wins" {
  fixture_new ki_ion
  printf '.Xmodmap\n' > "$FIX_REPO/link-ignore.txt"
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  run_link_sess wayland --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"i  .Xmodmap"* ]]
  [[ "$output" != *"x  .Xmodmap"* ]]
}

# ---- known issue: non-git repo silently reports zero [unlinked] ----------
# refresh_scan's git check-ignore error path skips every candidate when the
# repo is not a git repo, so --audit is silently blind to unlinked files.
# (Deliberately left unfixed: this repo is always a git repo, so the path is
# dead in practice; kept here as documentation if that ever changes.)
@test "known- audit on a non-git repo still reports [unlinked] candidates" {
  fixture_new ki_nogit
  run_link --yes
  [ "$status" -eq 0 ]
  printf 'extra\n' > "$FIX_HOME/.config/mpv/extra.conf"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .config/mpv/extra.conf
  [[ "$output" == *"[unlinked]"* ]]
}
