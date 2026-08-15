#!/usr/bin/env bats
#
# link-files.bats -- edge-case suite for link-files.bash, covering EXISTING
# behavior only (the committed script). No --diff assertions (out of scope);
# fixtures only, never the real $HOME.
#
# Every test builds a throwaway fixture repo + fake home (helpers.bash) and
# runs the script from the fixture copy. The OS is stubbed to Linux by
# default (setup()); overlay tests override with stub_uname Darwin. Test
# names are prefixed (link- classify- overlay- context- ignore- refresh-
# audit- picker- cli- guard-) so `bats --filter '^cli-'` etc. work.
#
# Known current behaviors locked in here (verified 2026-08-15):
#   * the numbered fallback menu consumes one stdin line; the confirmation
#     prompt consumes the next -- so piped runs need 'a'/'n'/'<n>' plus 'y'.
#     'a' alone links nothing (confirm reads EOF and exits 1).
#   * an ignore entry ADDED while the file is still linked surfaces in
#     --audit as `i [ignored]`.
#   * an ignore entry REMOVED while the file is unlinked surfaces as
#     `+ [missing]`.
#   * --force backs up real files (.bak.<STAMP>); foreign symlinks are only
#     replaced, never backed up.

load helpers

setup() {
  stub_uname Linux
}

# ================================================================ link- ===

@test "link- creates a new top-level link" {
  fixture_new link_top
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  assert_link .tmux.conf "$FIX_REPO/common/.tmux.conf"
}

@test "link- creates a new nested .config link with parent dirs" {
  fixture_new link_nested
  run_link --yes
  [ "$status" -eq 0 ]
  [ -d "$FIX_HOME/.config/mpv" ]
  [ -d "$FIX_HOME/.config/nvim" ]
  assert_link .config/mpv/mpv.conf "$FIX_REPO/common/.config/mpv/mpv.conf"
  assert_link .config/nvim/init.lua "$FIX_REPO/common/.config/nvim/init.lua"
}

@test "link- already-correct links are left alone (Nothing to do)" {
  fixture_new link_same
  run_link --yes
  [ "$status" -eq 0 ]
  run_link --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to do (5 links already correct)."* ]]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  assert_link .config/shell/os.sh "$FIX_REPO/linux/.config/shell/os.sh"
}

@test "link- a filtering pattern narrows the link set" {
  fixture_new link_pattern
  run_link --yes '.*nvim.*'
  [ "$status" -eq 0 ]
  assert_link .config/nvim/init.lua "$FIX_REPO/common/.config/nvim/init.lua"
  assert_no_link .zshrc
  assert_no_link .config/mpv/mpv.conf
  [[ "$output" != *".zshrc"* ]]
}

# =========================================================== classify- ===

@test "classify- old-scheme hard link is relinked to a symlink without --force" {
  fixture_new cl_hard
  ln "$FIX_REPO/common/.zshrc" "$FIX_HOME/.zshrc"   # hard link, same inode
  run_link --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"hard link"* ]]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  [ "$(stat -c %h "$FIX_REPO/common/.zshrc")" -eq 1 ]  # home link was the only extra ref
}

@test "classify- wrong-source symlink is relinked" {
  fixture_new cl_soft
  mkhome_link .zshrc "$FIX_REPO/common/.tmux.conf"
  run_link --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"relink"* ]]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "classify- foreign symlink is a conflict, skipped without --force" {
  fixture_new cl_foreign
  mkhome_link .zshrc /etc/passwd
  run_link --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"foreign link"* ]]
  [[ "$output" == *"conflict(s) skipped -- re-run with --force"* ]]
  [ -L "$FIX_HOME/.zshrc" ]
  [ "$(readlink "$FIX_HOME/.zshrc")" = "/etc/passwd" ]
}

@test "classify- foreign symlink is replaced by --force (never backed up)" {
  fixture_new cl_foreign_force
  mkhome_link .zshrc /etc/passwd
  run_link --force --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  # the script only backs up real files; a foreign symlink is replaced outright
  [ -z "$(find "$FIX_HOME" -maxdepth 1 -name '.zshrc.bak.*' -print -quit)" ]
}

@test "classify- real file conflict is skipped without --force, untouched" {
  fixture_new cl_real
  printf 'MYDATA\n' > "$FIX_HOME/.zshrc"
  run_link --yes
  [ "$status" -eq 0 ]
  [ -f "$FIX_HOME/.zshrc" ] && [ ! -L "$FIX_HOME/.zshrc" ]
  [ "$(cat "$FIX_HOME/.zshrc")" = "MYDATA" ]
  [[ "$output" == *"conflict(s) skipped -- re-run with --force"* ]]
}

@test "classify- --force backs up a real file to .bak.<STAMP> with content preserved" {
  fixture_new cl_backup
  printf 'MYDATA\n' > "$FIX_HOME/.zshrc"
  printf 'MYDATA\n' > "$BATS_TEST_TMPDIR/orig.zshrc"
  run_link --force --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  cmp "$FIX_HOME/.zshrc.bak."* "$BATS_TEST_TMPDIR/orig.zshrc"
}

@test "classify- --force --no-backup deletes the real file, no .bak created" {
  fixture_new cl_nobackup
  printf 'MYDATA\n' > "$FIX_HOME/.zshrc"
  run_link --force --no-backup --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  [ -z "$(find "$FIX_HOME" -maxdepth 1 -name '.zshrc.bak.*' -print -quit)" ]
}

@test "classify- --no-backup on a directory conflict refuses (exit 1)" {
  fixture_new cl_dir
  mkdir -p "$FIX_HOME/.config/nvim/init.lua"
  run_link --force --no-backup --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot replace a directory"* ]]
}

# ============================================================ overlay- ===

@test "overlay- common+linux collision: the linux overlay wins" {
  fixture_new ov_linux
  printf 'linux tmux\n' > "$FIX_REPO/linux/.tmux.conf"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .tmux.conf "$FIX_REPO/linux/.tmux.conf"
  [ "$(cat "$FIX_HOME/.tmux.conf")" = "linux tmux" ]
}

@test "overlay- Darwin: the macos overlay wins" {
  fixture_new ov_macos
  stub_uname Darwin
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .config/shell/os.sh "$FIX_REPO/macos/.config/shell/os.sh"
  assert_link .hushlogin "$FIX_REPO/macos/.hushlogin"
  [ "$(cat "$FIX_HOME/.config/shell/os.sh")" = "macos os" ]
}

@test "overlay- a linux-only file is not linked on Darwin" {
  fixture_new ov_platform
  stub_uname Darwin
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .Xmodmap
  assert_no_link .xinitrc
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "overlay- OS switch prunes links the other platform left behind" {
  fixture_new ov_switch
  stub_uname Darwin
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .hushlogin "$FIX_REPO/macos/.hushlogin"
  stub_uname Linux
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .hushlogin
  assert_link .config/shell/os.sh "$FIX_REPO/linux/.config/shell/os.sh"
}

@test "overlay- macos leftover on linux is stale, reported and pruned" {
  fixture_new ov_leftover
  stub_uname Darwin
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .hushlogin "$FIX_REPO/macos/.hushlogin"
  stub_uname Linux
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .hushlogin
  [[ "$output" == *"-  .hushlogin"* ]]
  [[ "$output" == *"stale link"* ]]
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .hushlogin
}

# ============================================================ context- ===

@test "context- session detection: wayland, x11, headless" {
  fixture_new ctx_detect
  run_link_sess wayland --audit
  [[ "$output" == *"audit context: wayland (neglecting: x11: .Xmodmap, x11: .xinitrc)"* ]]
  run_link_sess x11 --audit
  [[ "$output" == *"audit context: x11"* ]]
  [[ "$output" != *"neglecting"* ]]
  run_link_sess headless --audit
  [[ "$output" == *"audit context: headless (neglecting: x11: .Xmodmap, x11: .xinitrc)"* ]]
}

@test "context- x11-only file is not linked on wayland" {
  fixture_new ctx_waylink
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  assert_no_link .Xmodmap
  assert_no_link .xinitrc
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "context- x11-only file is not reported [missing] on wayland" {
  fixture_new ctx_wayaudit
  run_link_sess wayland --audit
  [ "$status" -eq 1 ]   # findings exist (the other 5 files), but not for .Xmodmap
  output_not_has_finding .Xmodmap
  output_not_has_finding .xinitrc
  output_has_finding .zshrc
}

@test "context- x11-only file is linked on an x11 session" {
  fixture_new ctx_x11
  run_link_sess x11 --yes
  [ "$status" -eq 0 ]
  assert_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  assert_link .xinitrc "$FIX_REPO/linux/.xinitrc"
}

@test "context- neglected-but-linked file is preserved by a normal run" {
  fixture_new ctx_preserve
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  assert_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "context- a pattern cannot resurrect a neglected file" {
  fixture_new ctx_pattern
  run_link_sess wayland --audit '.*Xmodmap'
  [ "$status" -eq 0 ]
  [[ "$output" == *"audit context: wayland"* ]]
  [[ "$output" == *"Audit clean"* ]]
  output_not_has_finding .Xmodmap
}

@test "context- neglinked x11 file is reported on wayland, not on x11" {
  fixture_new ctx_neglink
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  run_link_sess wayland --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"x  .Xmodmap"* ]]
  [[ "$output" == *"[neglected] wanted on: x11"* ]]
  # the same link on an x11 session is wanted: audit clean for it
  run_link_sess x11 --yes
  [ "$status" -eq 0 ]
  run_link_sess x11 --audit
  [ "$status" -eq 0 ]
  [[ "$output" != *"x  .Xmodmap"* ]]
  [[ "$output" == *"Audit clean"* ]]
}

@test "context- dangling neglected link is reported once as stale, never x" {
  fixture_new ctx_dangling
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  rm "$FIX_REPO/linux/.Xmodmap"
  run_link_sess wayland --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"-  .Xmodmap"* ]]
  [[ "$output" != *"x  .Xmodmap"* ]]
  [ "$(grep -cE '^[-x]  \.Xmodmap( |$)' <<< "$output")" -eq 1 ]
}

@test "context- a real file at a neglected path is never reported" {
  fixture_new ctx_real
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  printf 'MYDATA\n' > "$FIX_HOME/.Xmodmap"
  run_link_sess wayland --audit
  [ "$status" -eq 0 ]
  [[ "$output" != *"x  .Xmodmap"* ]]
  [[ "$output" != *"!  .Xmodmap"* ]]
  [[ "$output" == *"Audit clean"* ]]
}

@test "context- a pattern narrows the neglinked report" {
  fixture_new ctx_negpattern
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  mkhome_link .xinitrc "$FIX_REPO/linux/.xinitrc"
  run_link_sess wayland --audit '.*Xmodmap'
  [ "$status" -eq 1 ]
  [[ "$output" == *"x  .Xmodmap"* ]]
  [[ "$output" != *"x  .xinitrc"* ]]
}

@test "context- multiple wanted contexts are listed in file order" {
  fixture_new ctx_multictx
  printf 'headless: .Xmodmap\n' >> "$FIX_REPO/link-context.txt"
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  run_link_sess wayland --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"x  .Xmodmap"* ]]
  [[ "$output" == *"[neglected] wanted on: x11,headless"* ]]
}

# ============================================================= ignore- ===

@test "ignore- an ignored entry is not linked" {
  fixture_new ig_entry
  mkdir -p "$FIX_REPO/common/bin"
  printf 'github\n' > "$FIX_REPO/common/bin/.github"   # listed in link-ignore.txt
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link bin/.github
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "ignore- a directory entry excludes its whole subtree" {
  fixture_new ig_subtree
  mkdir -p "$FIX_REPO/common/.config/ranger/plugins/ranger_devicons/icons"
  printf 'plugin\n' > "$FIX_REPO/common/.config/ranger/plugins/ranger_devicons/plugin.vim"
  printf 'icon\n' > "$FIX_REPO/common/.config/ranger/plugins/ranger_devicons/icons/devicons.txt"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .config/ranger/plugins/ranger_devicons/plugin.vim
  assert_no_link .config/ranger/plugins/ranger_devicons/icons/devicons.txt
}

@test "ignore- comments and blank lines are ignored" {
  fixture_new ig_comments
  printf '# just a comment\n\n   # indented comment\n\n' > "$FIX_REPO/link-ignore.txt"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  assert_link .config/mpv/mpv.conf "$FIX_REPO/common/.config/mpv/mpv.conf"
}

@test "ignore- a trailing slash is normalized" {
  fixture_new ig_slash
  printf '.config/mpv/\n' >> "$FIX_REPO/link-ignore.txt"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .config/mpv/mpv.conf
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "ignore- prefix collision: .config/foo does not exclude .config/foobar" {
  fixture_new ig_prefix
  printf '.config/foo\n' >> "$FIX_REPO/link-ignore.txt"
  mkdir -p "$FIX_REPO/common/.config/foo"
  printf 'baz\n' > "$FIX_REPO/common/.config/foo/baz"
  printf 'foobar\n' > "$FIX_REPO/common/.config/foobar"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .config/foo/baz        # under the entry: excluded
  assert_link .config/foobar "$FIX_REPO/common/.config/foobar"  # exact-match only
}

@test "ignore- entry ADDED while still linked is reported i [ignored]" {
  fixture_new ig_added
  run_link --yes
  [ "$status" -eq 0 ]
  printf '.zshrc\n' >> "$FIX_REPO/link-ignore.txt"
  run_link --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"i  .zshrc"* ]]
  [[ "$output" == *"[ignored] linked but listed in link-ignore.txt"* ]]
  run_link --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
}

@test "ignore- entry REMOVED with a correct link is silent" {
  fixture_new ig_removed_linked
  mkdir -p "$FIX_REPO/common/bin"
  printf 'github\n' > "$FIX_REPO/common/bin/.github"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link bin/.github
  mkhome_link bin/.github "$FIX_REPO/common/bin/.github"
  grep -v '^bin/.github$' "$FIX_REPO/link-ignore.txt" > "$FIX_REPO/link-ignore.txt.tmp"
  mv "$FIX_REPO/link-ignore.txt.tmp" "$FIX_REPO/link-ignore.txt"
  run_link --audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Audit clean"* ]]
  output_not_has_finding bin/.github
}

@test "ignore- ignored but dangling link is still reported stale ([ ! -e ] wins)" {
  fixture_new ig_dangling
  run_link --yes
  [ "$status" -eq 0 ]
  printf '.zshrc\n' >> "$FIX_REPO/link-ignore.txt"
  rm "$FIX_REPO/common/.zshrc"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .zshrc
  [[ "$output" == *"stale link"* ]]
}

@test "ignore- entry REMOVED without a home link is reported [missing]" {
  fixture_new ig_removed
  mkdir -p "$FIX_REPO/common/bin"
  printf 'github\n' > "$FIX_REPO/common/bin/.github"
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link bin/.github
  grep -v '^bin/.github$' "$FIX_REPO/link-ignore.txt" > "$FIX_REPO/link-ignore.txt.tmp"
  mv "$FIX_REPO/link-ignore.txt.tmp" "$FIX_REPO/link-ignore.txt"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding bin/.github
  [[ "$output" == *"[missing]"* ]]
}

# ============================================================== stale- ===

@test "stale- dangling link in a still-existing dir is reported (exit 1)" {
  fixture_new st_dangling
  run_link --yes
  [ "$status" -eq 0 ]
  rm "$FIX_REPO/common/.zshrc"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .zshrc
  [[ "$output" == *"stale link"* ]]
}

@test "stale- dangling links in a fully-deleted dir are reported and pruned" {
  fixture_new st_deleted
  run_link --yes
  [ "$status" -eq 0 ]
  rm -rf "$FIX_REPO/common/.config"   # whole dir gone from the repo
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .config/mpv/mpv.conf
  output_has_finding .config/nvim/init.lua
  [[ "$output" == *"stale link"* ]]
  run_link --yes
  [ "$status" -eq 0 ]
  assert_no_link .config/mpv/mpv.conf
  assert_no_link .config/nvim/init.lua
  run_link --audit
  [ "$status" -eq 0 ]
}

@test "stale- a pattern narrows the stale report" {
  fixture_new st_pattern
  printf 'gone\n' > "$FIX_REPO/common/.gone"
  printf 'keep\n' > "$FIX_REPO/common/.keep"
  run_link --yes
  [ "$status" -eq 0 ]
  rm "$FIX_REPO/common/.gone" "$FIX_REPO/common/.keep"
  run_link --audit '.*gone.*'
  [ "$status" -eq 1 ]
  output_has_finding .gone
  output_not_has_finding .keep
}

@test "stale- a foreign symlink is never reported as stale or removed" {
  fixture_new st_foreign
  mkhome_link .zshrc /etc/passwd
  run_link --audit
  [ "$status" -eq 1 ]
  [[ "$output" != *"-  .zshrc"* ]]
  run_link --yes
  [ "$status" -eq 0 ]
  [ -L "$FIX_HOME/.zshrc" ]
  [ "$(readlink "$FIX_HOME/.zshrc")" = "/etc/passwd" ]
}

@test "stale- a relative symlink is never reported as stale" {
  fixture_new st_relative
  mkhome_link .zshrc ../repo/common/.zshrc
  run_link --audit
  [ "$status" -eq 1 ]
  [[ "$output" != *"-  .zshrc"* ]]
  run_link --yes
  [ "$status" -eq 0 ]
  [ -L "$FIX_HOME/.zshrc" ]
  [ "$(readlink "$FIX_HOME/.zshrc")" = "../repo/common/.zshrc" ]
}

# ============================================================ refresh- ===

@test "refresh- new file in a linked dir is captured to common and symlinked back" {
  fixture_new rf_capture git
  run_link --yes
  [ "$status" -eq 0 ]
  printf 'extra\n' > "$FIX_HOME/.config/mpv/extra.conf"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"extra.conf [refresh] -> common"* ]]
  [ -f "$FIX_REPO/common/.config/mpv/extra.conf" ]
  [ "$(cat "$FIX_REPO/common/.config/mpv/extra.conf")" = "extra" ]
  assert_link .config/mpv/extra.conf "$FIX_REPO/common/.config/mpv/extra.conf"
}

@test "refresh- overlay-first: captured into the OS overlay when it has the dir" {
  fixture_new rf_overlay git
  mkdir -p "$FIX_REPO/linux/.config/mpv"
  mkdir -p "$FIX_HOME/.config/mpv"
  printf 'extra\n' > "$FIX_HOME/.config/mpv/extra.conf"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [ -f "$FIX_REPO/linux/.config/mpv/extra.conf" ]
  assert_link .config/mpv/extra.conf "$FIX_REPO/linux/.config/mpv/extra.conf"
}

@test "refresh- ignored files are skipped" {
  fixture_new rf_ignored git
  printf '.config/mpv/ignoreme.conf\n' >> "$FIX_REPO/link-ignore.txt"
  mkdir -p "$FIX_HOME/.config/mpv"
  printf 'nope\n' > "$FIX_HOME/.config/mpv/ignoreme.conf"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to refresh."* ]]
  [ -f "$FIX_HOME/.config/mpv/ignoreme.conf" ] && [ ! -L "$FIX_HOME/.config/mpv/ignoreme.conf" ]
  [ ! -e "$FIX_REPO/common/.config/mpv/ignoreme.conf" ]
}

@test "refresh- gitignored files are skipped" {
  fixture_new rf_gitignore git
  printf '.config/mpv/secret.conf\n' > "$FIX_REPO/.gitignore"
  mkdir -p "$FIX_HOME/.config/mpv"
  printf 'secret\n' > "$FIX_HOME/.config/mpv/secret.conf"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to refresh."* ]]
  [ -f "$FIX_HOME/.config/mpv/secret.conf" ] && [ ! -L "$FIX_HOME/.config/mpv/secret.conf" ]
  [ ! -e "$FIX_REPO/common/.config/mpv/secret.conf" ]
}

@test "refresh- *.bak.* files are skipped" {
  fixture_new rf_bak git
  mkdir -p "$FIX_HOME/.config/mpv"
  printf 'bak\n' > "$FIX_HOME/.config/mpv/mpv.conf.bak.20260101"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to refresh."* ]]
  [ -f "$FIX_HOME/.config/mpv/mpv.conf.bak.20260101" ] && [ ! -L "$FIX_HOME/.config/mpv/mpv.conf.bak.20260101" ]
  [ ! -e "$FIX_REPO/common/.config/mpv/mpv.conf.bak.20260101" ]
}

@test "refresh- .git/* files are skipped" {
  fixture_new rf_gitdir git
  mkdir -p "$FIX_HOME/.config/mpv/.git"
  printf 'x\n' > "$FIX_HOME/.config/mpv/.git/config"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to refresh."* ]]
  [ ! -e "$FIX_REPO/common/.config/mpv/.git" ]
}

@test "refresh- files neglected for the session are skipped" {
  fixture_new rf_neglect git
  printf 'x11: .config/shell/x11extra.sh\n' >> "$FIX_REPO/link-context.txt"
  mkdir -p "$FIX_HOME/.config/shell"
  printf 'x11\n' > "$FIX_HOME/.config/shell/x11extra.sh"
  run_link_sess wayland --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to refresh."* ]]
  [ -f "$FIX_HOME/.config/shell/x11extra.sh" ] && [ ! -L "$FIX_HOME/.config/shell/x11extra.sh" ]
  [ ! -e "$FIX_REPO/common/.config/shell/x11extra.sh" ]
}

@test "refresh- an existing repo file is never overwritten" {
  fixture_new rf_noover git
  printf 'REPO-VER\n' > "$FIX_REPO/common/.config/mpv/exists.conf"
  mkdir -p "$FIX_HOME/.config/mpv"
  printf 'HOME-VER\n' > "$FIX_HOME/.config/mpv/exists.conf"
  run_link --refresh --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to refresh."* ]]
  [ "$(cat "$FIX_REPO/common/.config/mpv/exists.conf")" = "REPO-VER" ]
  [ -f "$FIX_HOME/.config/mpv/exists.conf" ] && [ ! -L "$FIX_HOME/.config/mpv/exists.conf" ]
  [ "$(cat "$FIX_HOME/.config/mpv/exists.conf")" = "HOME-VER" ]
}

@test "refresh- --dry-run changes nothing" {
  fixture_new rf_dry git
  mkdir -p "$FIX_HOME/.config/mpv"
  printf 'extra\n' > "$FIX_HOME/.config/mpv/extra.conf"
  run_link --refresh --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"extra.conf [refresh] -> common"* ]]
  [ -f "$FIX_HOME/.config/mpv/extra.conf" ] && [ ! -L "$FIX_HOME/.config/mpv/extra.conf" ]
  [ ! -e "$FIX_REPO/common/.config/mpv/extra.conf" ]
}

# ============================================================== audit- ===

@test "audit- all-correct home is clean (exit 0)" {
  fixture_new au_clean
  run_link --yes
  [ "$status" -eq 0 ]
  run_link --audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Audit clean (5 links correct)."* ]]
}

@test "audit- missing links are reported [missing] (exit 1)" {
  fixture_new au_missing
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .zshrc
  output_has_finding .tmux.conf
  [[ "$output" == *"[missing]"* ]]
  [[ "$output" == *"Audit findings: 5."* ]]
}

@test "audit- wrong-source symlink is reported [relink] (exit 1)" {
  fixture_new au_relink
  mkhome_link .zshrc "$FIX_REPO/common/.tmux.conf"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .zshrc
  [[ "$output" == *"[relink]"* ]]
}

@test "audit- real-file conflict is reported [conflict] (exit 1)" {
  fixture_new au_conflict
  printf 'DATA\n' > "$FIX_HOME/.zshrc"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .zshrc
  [[ "$output" == *"[conflict]"* ]]
}

@test "audit- repo-pointing link no longer wanted is a stale link (exit 1)" {
  fixture_new au_stale
  mkhome_link .hushlogin "$FIX_REPO/macos/.hushlogin"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .hushlogin
  [[ "$output" == *"-  .hushlogin"* ]]
  [[ "$output" == *"stale link"* ]]
}

@test "audit- ignored-but-linked file is reported i [ignored] (exit 1)" {
  fixture_new au_ignored
  run_link --yes
  [ "$status" -eq 0 ]
  printf '.zshrc\n' >> "$FIX_REPO/link-ignore.txt"
  run_link --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"i  .zshrc"* ]]
  [[ "$output" == *"[ignored] linked but listed in link-ignore.txt"* ]]
}

@test "audit- session-neglected link is reported x [neglected] (exit 1)" {
  fixture_new au_neglinked
  run_link_sess wayland --yes
  [ "$status" -eq 0 ]
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  run_link_sess wayland --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"x  .Xmodmap"* ]]
  [[ "$output" == *"[neglected] wanted on: x11"* ]]
}

@test "audit- new real file inside a linked dir is [unlinked] (exit 1)" {
  fixture_new au_unlinked git
  run_link --yes
  [ "$status" -eq 0 ]
  printf 'extra\n' > "$FIX_HOME/.config/mpv/extra.conf"
  run_link --audit
  [ "$status" -eq 1 ]
  output_has_finding .config/mpv/extra.conf
  [[ "$output" == *"[unlinked]"* ]]
}

@test "audit- a pattern narrows the report" {
  fixture_new au_pattern
  run_link --audit '.*nvim.*'
  [ "$status" -eq 1 ]
  output_has_finding .config/nvim/init.lua
  output_not_has_finding .zshrc
}

@test "audit- the home directory is bit-for-bit unchanged after --audit" {
  fixture_new au_readonly
  run_link --yes
  [ "$status" -eq 0 ]
  rm "$FIX_HOME/.tmux.conf"                  # real-file conflict (findings exist)
  printf 'DATA\n' > "$FIX_HOME/.tmux.conf"
  cp -a "$FIX_HOME" "$BATS_TEST_TMPDIR/home.snap"
  run_link --audit
  [ "$status" -eq 1 ]
  run diff -rq "$BATS_TEST_TMPDIR/home.snap" "$FIX_HOME"
  [ "$status" -eq 0 ]
}

# ============================================================= picker- ===

@test "picker- fallback menu 'a' (all) then confirm links everything" {
  fixture_new pk_all
  run_link_stdin $'a\ny\n'
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  assert_link .tmux.conf "$FIX_REPO/common/.tmux.conf"
  assert_link .config/mpv/mpv.conf "$FIX_REPO/common/.config/mpv/mpv.conf"
  assert_link .config/nvim/init.lua "$FIX_REPO/common/.config/nvim/init.lua"
  assert_link .config/shell/os.sh "$FIX_REPO/linux/.config/shell/os.sh"
  assert_no_link .Xmodmap   # neglected for this headless session
}

@test "picker- fallback menu 'n' selects nothing" {
  fixture_new pk_none
  run_link_stdin $'n\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing selected."* ]]
  [ -z "$(ls -A "$FIX_HOME")" ]
}

@test "picker- a single number links just that entry" {
  fixture_new pk_number
  # menu order: OSDIR rels sorted first (.config/shell/os.sh), then common
  # rels sorted (.config/mpv/mpv.conf, .config/nvim/init.lua, .tmux.conf, .zshrc)
  run_link_stdin $'1\ny\n'
  [ "$status" -eq 0 ]
  assert_link .config/shell/os.sh "$FIX_REPO/linux/.config/shell/os.sh"
  assert_no_link .zshrc
  assert_no_link .config/mpv/mpv.conf
}

@test "picker- a range links the selected entries only" {
  fixture_new pk_range
  run_link_stdin $'2-3\ny\n'
  [ "$status" -eq 0 ]
  assert_link .config/mpv/mpv.conf "$FIX_REPO/common/.config/mpv/mpv.conf"
  assert_link .config/nvim/init.lua "$FIX_REPO/common/.config/nvim/init.lua"
  assert_no_link .zshrc
  assert_no_link .tmux.conf
  assert_no_link .config/shell/os.sh
}

@test "picker- nothing to link when every managed file is already linked" {
  fixture_new pk_done
  run_link --yes
  [ "$status" -eq 0 ]
  run_link_stdin $'a\n'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to link: every managed file is already linked correctly."* ]]
}

# =============================================================== cli- ===

@test "cli- unknown option exits 1" {
  fixture_new cli_unknown
  run_link --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *'unknown option "--bogus"'* ]]
}

@test "cli- --no-backup without --force exits 1" {
  fixture_new cli_nobackup
  run_link --no-backup
  [ "$status" -eq 1 ]
  [[ "$output" == *"error: --no-backup requires --force"* ]]
}

@test "cli- two filtering patterns exits 1" {
  fixture_new cli_two
  run_link foo bar
  [ "$status" -eq 1 ]
  [[ "$output" == *"you can only specify one filtering pattern"* ]]
}

@test "cli- --help shows usage and exits 0" {
  fixture_new cli_help
  run_link --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE:"* ]]
  [[ "$output" == *"--no-backup"* ]]
  [[ "$output" == *"--audit"* ]]
  run_link -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE:"* ]]
}

@test "cli- --reverse is removed and exits 1" {
  fixture_new cli_reverse
  run_link --reverse
  [ "$status" -eq 1 ]
  [[ "$output" == *"--reverse was removed"* ]]
}

# ================================================================ fix- ===

@test "fix- six-state resolution: missing, wrong-source, conflict, stale, ignored, neglinked" {
  fixture_new fx_six
  run_link --yes
  [ "$status" -eq 0 ]
  # missing: a repo file with no home link yet
  printf 'new\n' > "$FIX_REPO/common/.newfile"
  # wrong-source: ~/.tmux.conf now points at the wrong repo file
  rm -f "$FIX_HOME/.tmux.conf"
  mkhome_link .tmux.conf "$FIX_REPO/common/.zshrc"
  # conflict: a real file at a repo path
  rm -f "$FIX_HOME/.config/mpv/mpv.conf"
  printf 'MYDATA\n' > "$FIX_HOME/.config/mpv/mpv.conf"
  # stale: dangling link, repo file deleted
  rm "$FIX_REPO/common/.config/nvim/init.lua"
  # ignored: entry added to link-ignore.txt while still linked
  printf '.config/shell/os.sh\n' >> "$FIX_REPO/link-ignore.txt"
  # neglinked: ~/.Xmodmap linked while on wayland
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"

  run_link_sess wayland --fix --yes
  [ "$status" -eq 0 ]
  # missing -> created
  assert_link .newfile "$FIX_REPO/common/.newfile"
  # wrong-source -> relinked
  assert_link .tmux.conf "$FIX_REPO/common/.tmux.conf"
  # conflict -> backed up and linked
  assert_link .config/mpv/mpv.conf "$FIX_REPO/common/.config/mpv/mpv.conf"
  [ -f "$FIX_HOME/.config/mpv/mpv.conf.bak."* ]
  cmp "$FIX_HOME/.config/mpv/mpv.conf.bak."* <(printf 'MYDATA\n')
  # stale -> removed
  assert_no_link .config/nvim/init.lua
  # ignored -> removed
  assert_no_link .config/shell/os.sh
  # neglinked -> removed
  assert_no_link .Xmodmap

  # re-audit clean
  run_link_sess wayland --audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Audit clean"* ]]
}

@test "fix- dry-run previews all six markers and changes nothing" {
  fixture_new fx_dry
  run_link --yes
  [ "$status" -eq 0 ]
  printf 'new\n' > "$FIX_REPO/common/.newfile"
  rm -f "$FIX_HOME/.tmux.conf"
  mkhome_link .tmux.conf "$FIX_REPO/common/.zshrc"
  rm -f "$FIX_HOME/.config/mpv/mpv.conf"
  printf 'MYDATA\n' > "$FIX_HOME/.config/mpv/mpv.conf"
  rm "$FIX_REPO/common/.config/nvim/init.lua"
  printf '.config/shell/os.sh\n' >> "$FIX_REPO/link-ignore.txt"
  mkhome_link .Xmodmap "$FIX_REPO/linux/.Xmodmap"
  cp -a "$FIX_HOME" "$BATS_TEST_TMPDIR/home.snap"

  run_link_sess wayland --fix --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"+  .newfile"* ]]              # missing
  [[ "$output" == *"*  .tmux.conf"* ]]            # wrong-source
  [[ "$output" == *"~  .config/mpv/mpv.conf"* ]]  # conflict (--fix implies --force)
  [[ "$output" == *"-  .config/nvim/init.lua"* ]] # stale
  [[ "$output" == *"i  .config/shell/os.sh"* ]]   # ignored
  [[ "$output" == *"x  .Xmodmap"* ]]              # neglinked
  # --no-dereference: the stale fixture link is dangling, plain diff -rq
  # would fail to stat its missing target
  run diff -rq --no-dereference "$BATS_TEST_TMPDIR/home.snap" "$FIX_HOME"
  [ "$status" -eq 0 ]
}

@test "fix- --fix --audit exits 1 with the exclusivity error" {
  fixture_new fx_excl_audit
  run_link --fix --audit
  [ "$status" -eq 1 ]
  [[ "$output" == *"error: --fix cannot be combined with --audit or --refresh"* ]]
}

@test "fix- --fix --refresh exits 1 with the exclusivity error" {
  fixture_new fx_excl_refresh
  run_link --fix --refresh
  [ "$status" -eq 1 ]
  [[ "$output" == *"error: --fix cannot be combined with --audit or --refresh"* ]]
}

@test "fix- a pattern narrows the fix to matching paths" {
  fixture_new fx_pattern
  run_link --yes
  [ "$status" -eq 0 ]
  rm "$FIX_REPO/common/.zshrc" "$FIX_REPO/common/.tmux.conf"
  run_link --fix --yes '.*zshrc.*'
  [ "$status" -eq 0 ]
  assert_no_link .zshrc          # stale, matched -> removed
  [ -L "$FIX_HOME/.tmux.conf" ]  # stale, not matched -> left dangling
}

@test "fix- never opens the picker (one stdin line reaches the confirm prompt)" {
  fixture_new fx_nopicker
  # if the picker opened it would consume the 'y' and confirm would read EOF
  # (exit 1, nothing linked); reaching the confirm prompt proves no picker
  run_link_stdin $'y\n' --fix
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  assert_link .tmux.conf "$FIX_REPO/common/.tmux.conf"
}

@test "fix- --no-backup on a directory conflict still refuses" {
  fixture_new fx_dir
  mkdir -p "$FIX_HOME/.config/nvim/init.lua"
  run_link --fix --no-backup --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot replace a directory"* ]]
}

@test "fix- implies --force: a real-file conflict is backed up without --force" {
  fixture_new fx_force
  printf 'MYDATA\n' > "$FIX_HOME/.zshrc"
  run_link --fix --yes
  [ "$status" -eq 0 ]
  assert_link .zshrc "$FIX_REPO/common/.zshrc"
  [ -f "$FIX_HOME/.zshrc.bak."* ]
  cmp "$FIX_HOME/.zshrc.bak."* <(printf 'MYDATA\n')
}

# ============================================================== guard- ===

@test "guard- a dir symlink resolving inside the repo is refused" {
  fixture_new gr_guard
  # ~/.config -> <repo>/common/.config, so the parent dir of the .config rels
  # resolves inside the repo. Use a RELATIVE target: an absolute repo target
  # is now caught by find_stale's -lname scan and removed as stale before
  # apply runs, so the guard is only reachable when the stale scan skips the
  # link (relative targets don't match -lname "$REPO/*").
  ln -s "../repo/common/.config" "$FIX_HOME/.config"
  run_link_stdin $'2-3\ny\n'
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing"* ]]
  [[ "$output" == *"resolves inside the repo"* ]]
  [ -L "$FIX_HOME/.config" ]
  [ "$(readlink "$FIX_HOME/.config")" = "../repo/common/.config" ]
}
