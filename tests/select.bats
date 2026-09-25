#!/usr/bin/env bats
#
# select.bats -- unit tests for the typed multi-select parser used by the
# setup scripts (common/bin/setup-os, setup/agent-skills.sh). Those scripts
# take no test harness of their own, so expand_selection is extracted and
# driven directly: no terminal, no fixtures, no side effects.
#
# The awk extractor matches `expand_selection() {` up to the first `}` at
# column 0, so keep the function top-level and end it with a bare `}`.

ROOT="$BATS_TEST_DIRNAME/.."

# assert_sel <script> <count> <input> <expected-csv>
# Runs that script's expand_selection and compares the 1-based indices, as a
# trailing-comma CSV, against <expected-csv>. stderr (the "ignoring" notes) is
# dropped so invalid-token cases can be asserted on stdout alone.
assert_sel() {
  eval "$(awk '/^expand_selection\(\)/,/^}/' "$1")"
  local got
  got="$(expand_selection "$2" "$3" 2>/dev/null | tr '\n' ',')"
  [ "$got" = "$4" ] || { printf 'expand_selection %s %s => [%s], want [%s]\n' \
    "$2" "$3" "$got" "$4" >&2; return 1; }
}

# ============================================================ setup-os ===

@test "select- setup-os: comma- and space-separated numbers and ranges" {
  assert_sel "$ROOT/common/bin/setup-os" 8 "1,3 5-7" "1,3,5,6,7,"
  assert_sel "$ROOT/common/bin/setup-os" 8 "1, 3-4"  "1,3,4,"
}

@test "select- setup-os: 'a' is all, 'n' and empty are none" {
  assert_sel "$ROOT/common/bin/setup-os" 3 "a"     "1,2,3,"
  assert_sel "$ROOT/common/bin/setup-os" 3 "n"     ""
  assert_sel "$ROOT/common/bin/setup-os" 3 ""      ""
}

@test "select- setup-os: out-of-range and invalid tokens are dropped" {
  assert_sel "$ROOT/common/bin/setup-os" 5 "1,9"   "1,"
  assert_sel "$ROOT/common/bin/setup-os" 5 "abc"   ""
}

# ===================================================== agent-skills ===

@test "select- agent-skills: comma- and space-separated numbers and ranges" {
  assert_sel "$ROOT/setup/agent-skills.sh" 8 "1,3 5-7" "1,3,5,6,7,"
  assert_sel "$ROOT/setup/agent-skills.sh" 8 "1, 3-4"  "1,3,4,"
}

@test "select- agent-skills: 'a' and empty are all, 'n' is none" {
  assert_sel "$ROOT/setup/agent-skills.sh" 3 "a" "1,2,3,"
  assert_sel "$ROOT/setup/agent-skills.sh" 3 ""  "1,2,3,"
  assert_sel "$ROOT/setup/agent-skills.sh" 3 "n" ""
}
