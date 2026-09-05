#!/usr/bin/env bash
set -euo pipefail

# A statement that ran counts as covered on every line it spans, whichever way
# it spans them. #722 established that for a backslash chain; an array literal,
# a multi-line string and a heredoc are the same statement over several lines
# and used to cost one uncovered line each (#1338).
#
# End to end rather than at the reader, because the defect depended on where the
# DEBUG trap put the hit: Bash 3.2 reports an array assignment on its closing
# `)` -- a line the classifier calls non-executable, so the hit was dropped
# outright -- and Bash 5.x reports its opening line. Only a real run exercises
# whichever of the two this machine does.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

# A source file whose every function spans lines a different way, and a test
# that runs all of them.
function _project() { # $1 = dir
  mkdir -p "$1/src"
  cat >"$1/src/multiline.sh" <<'SRC'
#!/usr/bin/env bash

function multi_line_array() {
  local commands=(
    "start"
    "stop"
    "status"
  )

  printf '%s\n' "${commands[@]}"
}

function backslash_continuation() {
  printf '%s\n' \
    "start" \
    "stop"
}

function multi_line_string() {
  printf '%s' '{
    "index": "spend",
    "alias": "filters"
  }'
}

function here_document() {
  cat <<EOF
one
two
EOF
}
SRC
  cat >"$1/t_test.sh" <<'TEST'
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/src/multiline.sh"

function test_multi_line_array() {
  assert_contains "start" "$(multi_line_array)"
}

function test_backslash_continuation() {
  assert_contains "start" "$(backslash_continuation)"
}

function test_multi_line_string() {
  assert_contains "spend" "$(multi_line_string)"
}

function test_here_document() {
  assert_contains "one" "$(here_document)"
}
TEST
}

function _run_coverage() { # $1 = dir
  local dir="$1"
  shift
  (cd "$dir" && BASHUNIT_COVERAGE_SHOW_UNCOVERED=true \
    "$ROOT_DIR/bashunit" --no-parallel --coverage --coverage-paths src \
    --no-coverage-report "$@" t_test.sh 2>&1) || true
}

function test_every_line_of_a_multi_line_statement_that_ran_is_covered() {
  local dir
  dir="$(bashunit::temp_dir)"
  _project "$dir"

  local output
  output="$(_run_coverage "$dir" | strip_ansi)"

  assert_contains "16/ 16 lines (100%)" "$output"
  assert_not_contains "Uncovered Lines" "$output"
}

# The same numbers have to come out of the LCOV writer, which reaches them
# through the batch awk pass rather than the Bash reader.
function test_the_lcov_report_agrees_with_the_terminal_report() {
  local dir
  dir="$(bashunit::temp_dir)"
  _project "$dir"

  (cd "$dir" && "$ROOT_DIR/bashunit" --no-parallel --coverage \
    --coverage-paths src --coverage-report lcov.info \
    t_test.sh >/dev/null 2>&1) || true

  assert_file_contains "$dir/lcov.info" "LF:16"
  assert_file_contains "$dir/lcov.info" "LH:16"
}

# A span nothing ran still counts against the file: the fix credits statements
# that executed, it does not remove lines from the denominator.
function test_a_multi_line_statement_that_never_ran_stays_uncovered() {
  local dir
  dir="$(bashunit::temp_dir)"
  _project "$dir"
  cat >>"$dir/src/multiline.sh" <<'SRC'

function never_called() {
  local unused=(
    "a"
    "b"
  )
  printf '%s\n' "${unused[@]}"
}
SRC

  local output
  output="$(_run_coverage "$dir" | strip_ansi)"

  assert_contains "16/ 20 lines" "$output"
  assert_matches "src/multiline.sh:[0-9]+-[0-9]+" "$output"
}
