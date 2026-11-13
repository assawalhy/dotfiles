#!/usr/bin/env bats
#
# hc-resume.bats -- unit tests for the resume command builder, the shell
# detector, and the snapshot-driven dry run in common/.local/bin/hc-resume.
#
# No herdr-core and no network: the pure functions are extracted and driven
# directly, and the dry run reads a fixture snapshot via XDG_STATE_HOME.
#
# The awk extractor matches `func() {` up to the first `}` at column 0, so keep
# every function under test top-level and end it with a bare `}`.

ROOT="$BATS_TEST_DIRNAME/.."
SCRIPT="$ROOT/common/.local/bin/hc-resume"

# load_functions -- eval the two pure helpers out of the real script.
load_functions() {
  eval "$(awk '/^is_shell_name\(\)/,/^}/' "$SCRIPT")"
  eval "$(awk '/^resume_command\(\)/,/^}/' "$SCRIPT")"
}

# write_state <json> -- a fixture snapshot the dry run can read.
write_state() {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/hc-resume"
  printf '%s\n' "$1" >"$XDG_STATE_HOME/hc-resume/state.json"
}

@test "resume-command: claude continues its last conversation" {
  load_functions
  [ "$(resume_command claude)" = "claude --continue" ]
}

@test "resume-command: launch flags are kept" {
  load_functions
  [ "$(resume_command claude --dangerously-skip-permissions)" = \
    "claude --dangerously-skip-permissions --continue" ]
}

@test "resume-command: a continue flag is replaced, not duplicated" {
  load_functions
  [ "$(resume_command claude -c)" = "claude --continue" ]
  [ "$(resume_command claude --continue --model opus)" = "claude --model opus --continue" ]
}

@test "resume-command: resume and session flags drop their values" {
  load_functions
  [ "$(resume_command claude --resume abc123)" = "claude --continue" ]
  [ "$(resume_command claude --resume=abc123)" = "claude --continue" ]
  [ "$(resume_command opencode -s ses_42 --auto)" = "opencode --auto --continue" ]
}

@test "resume-command: codex uses its subcommand form" {
  load_functions
  [ "$(resume_command codex)" = "codex resume --last" ]
}

@test "resume-command: other programs are not resumed" {
  load_functions
  run resume_command zsh
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "shell detection: shells yes, agents no" {
  load_functions
  is_shell_name zsh
  is_shell_name /run/current-system/sw/bin/bash
  ! is_shell_name claude
  ! is_shell_name opencode
}

@test "dry run: one line per resumable pane, shells skipped" {
  write_state '{"ts":1,"panes":{
    "t1":{"cwd":"/a","name":"claude","cmd":"claude --continue","where":"a / 1"},
    "t2":{"cwd":"/a","name":"zsh","cmd":"","where":"a / 1"}}}'
  run "$SCRIPT" resume --dry-run
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
  [[ "$output" == *"claude --continue"* ]]
}

@test "dry run: a second pane on the same agent and cwd is skipped" {
  write_state '{"ts":1,"panes":{
    "t1":{"cwd":"/a","name":"claude","cmd":"claude --continue","where":""},
    "t2":{"cwd":"/a","name":"claude","cmd":"claude --continue","where":""}}}'
  run "$SCRIPT" resume --dry-run
  [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
}

@test "dry run: --only narrows to one pane" {
  write_state '{"ts":1,"panes":{
    "t1":{"cwd":"/a","name":"claude","cmd":"claude --continue","where":""},
    "t2":{"cwd":"/b","name":"opencode","cmd":"opencode --continue","where":""}}}'
  run "$SCRIPT" resume --dry-run --only t2
  [ "$status" -eq 0 ]
  [ "$output" = "t2"$'\t'"/b"$'\t'"opencode --continue" ]
}

@test "resume without a snapshot is a quiet no-op" {
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$XDG_STATE_HOME"
  run "$SCRIPT" resume --dry-run
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
