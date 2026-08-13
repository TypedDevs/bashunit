#!/usr/bin/env bash
set -euo pipefail

# A coverage run that tracked no executable line at all reports "Coverage 0% is
# below minimum N%", which reads as "your tests cover nothing" when the actual
# cause is usually that nothing was *found* to cover -- a mistyped
# --coverage-paths, a directory that holds no shell files, or sources that are
# all comments. The number is accurate and the diagnosis is wrong, which is the
# expensive kind of message (#1171).

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

# A project with one real source file and a passing test that touches nothing.
function _project() { # $1 = dir
  mkdir -p "$1/src"
  printf '%s\n' '#!/usr/bin/env bash' 'function real_fn() { echo hi; }' >"$1/src/real.sh"
  printf '%s\n' '#!/usr/bin/env bash' 'function test_nothing() { assert_same 1 1; }' \
    >"$1/t_test.sh"
}

function _run_coverage() { # $1 = dir, $@ = extra flags
  local dir="$1"
  shift
  (cd "$dir" && "$ROOT_DIR/bashunit" --no-parallel --coverage "$@" t_test.sh 2>&1) || true
}

function test_a_path_that_tracks_nothing_says_so_rather_than_blaming_coverage() {
  local dir
  dir="$(bashunit::temp_dir)"
  _project "$dir"

  local output
  output="$(_run_coverage "$dir" --coverage-paths srcc/ --coverage-min 80 | strip_ansi)"

  assert_contains "no executable lines" "$output"
  assert_contains "coverage-paths" "$output"
}

# The gate must still fail: a misconfigured run passing an 80% requirement
# silently is worse than either message.
function test_a_run_that_tracks_nothing_still_fails_the_minimum() {
  local dir
  dir="$(bashunit::temp_dir)"
  _project "$dir"

  local code=0
  (cd "$dir" && "$ROOT_DIR/bashunit" --no-parallel --coverage \
    --coverage-paths srcc/ --coverage-min 80 t_test.sh >/dev/null 2>&1) || code=$?

  assert_general_error "" "" "$code"
}

# A real path with real uncovered lines keeps the percentage message: that one
# is accurate and is what the flag exists to report.
function test_genuinely_uncovered_code_still_reports_the_percentage() {
  local dir
  dir="$(bashunit::temp_dir)"
  _project "$dir"

  local output
  output="$(_run_coverage "$dir" --coverage-paths src/ --coverage-min 80 | strip_ansi)"

  assert_contains "below minimum" "$output"
  assert_not_contains "no executable lines" "$output"
}
