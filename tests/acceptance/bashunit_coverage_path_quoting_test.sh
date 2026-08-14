#!/usr/bin/env bash
set -euo pipefail

# The DEBUG trap filters by baking the coverage paths into a `case` pattern as
# syntax -- the alternation has to arrive as syntax or `|` would not split. The
# literal path segments were interpolated unquoted, so any path containing a
# space produced a trap that does not parse:
#
#   debug trap: line 265: syntax error near unexpected token `src/*'
#
# The damage is not cosmetic: the trap fails on every line, stderr fills with
# 75 syntax errors for a one-test run, the file reports 0% because record_line
# never runs, and the test itself is marked failed although its assertion
# passed (#1245).
#
# A path is a literal, not a pattern, so the fix quotes the literal parts and
# leaves `*` and `|` as syntax.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

# A project whose source directory name contains $1.
function _project_with_dir() { # $1 = directory name
  local dir
  dir="$(bashunit::temp_dir)"
  mkdir -p "$dir/$1"
  printf '%s\n' '#!/usr/bin/env bash' 'function add() { echo $(( $1 + $2 )); }' \
    >"$dir/$1/lib.sh"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "source \"./\$COVERAGE_DIR/lib.sh\""
    printf '%s\n' 'function test_add() { assert_same 3 "$(add 1 2)"; }'
  } >"$dir/t_test.sh"
  printf '%s' "$dir"
}

function _run_coverage() { # $1 = project dir, $2 = source dir name
  (cd "$1" && COVERAGE_DIR="$2" "$BASHUNIT_BIN" --no-parallel --coverage \
    --coverage-paths "$2/" t_test.sh 2>&1) || true
}

function test_a_coverage_path_with_a_space_does_not_break_the_trap() {
  local dir
  dir="$(_project_with_dir "my src")"

  local output
  output="$(_run_coverage "$dir" "my src")"

  assert_not_contains "syntax error" "$output"
}

# The test must still pass: a broken trap failed it while its assertion passed.
function test_a_coverage_path_with_a_space_keeps_the_test_passing() {
  local dir
  dir="$(_project_with_dir "my src")"

  local output
  output="$(_run_coverage "$dir" "my src" | strip_ansi)"

  assert_contains "1 passed" "$output"
  assert_not_contains "1 failed" "$output"
}

# And coverage must actually be recorded, not silently reported as 0%.
function test_a_coverage_path_with_a_space_still_records_lines() {
  local dir
  dir="$(_project_with_dir "my src")"

  local output
  output="$(_run_coverage "$dir" "my src" | strip_ansi)"

  assert_not_contains "0/  1 lines" "$output"
}

# An apostrophe would close the quote the fix adds, so it has to be escaped as
# '\'' -- and the literal spelling of that cannot be written inline, because
# the replacement in ${var//pat/repl} processes backslashes and hands it back
# mangled.
function test_a_coverage_path_with_an_apostrophe_does_not_break_the_trap() {
  local dir
  dir="$(_project_with_dir "it's src")"

  local output
  output="$(_run_coverage "$dir" "it's src" | strip_ansi)"

  assert_not_contains "syntax error" "$output"
  assert_contains "1 passed" "$output"
}

# A plain path must keep working exactly as before.
function test_a_plain_coverage_path_is_unaffected() {
  local dir
  dir="$(_project_with_dir "src")"

  local output
  output="$(_run_coverage "$dir" "src" | strip_ansi)"

  assert_not_contains "syntax error" "$output"
  assert_contains "1 passed" "$output"
}
