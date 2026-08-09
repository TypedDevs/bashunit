#!/usr/bin/env bash
set -euo pipefail

# Regression guards for #836. A failing set_up_before_script used to produce
# three different outcomes depending on the shape of the hook's last statement
# and the bash version: visible failure (ERR-trap path), silently ignored
# (&&-guard on bash 3.2, real hook status was discarded), or silent failures
# with an off-by-one count (bash >= 4, where the ERR trap fired a second time
# in execute_file_hook's own scope and returned before the failure was
# recorded). One defined behavior now: every test in the file is marked failed
# with an attributed message, counts stay consistent, and the suite continues.

FIXTURES="tests/acceptance/fixtures/hook_failure"

function test_hook_failure_is_attributed_and_suite_continues() {
  local output
  local exit_code=0
  # --detailed: a parent running --simple still exports it (#837), and simple
  # mode would drop the attributed progress lines this test greps for.
  output=$(./bashunit --no-parallel --detailed --skip-env-file \
    "$FIXTURES/plain_hook.sh" "$FIXTURES/guard_hook.sh" "$FIXTURES/later.sh" 2>&1) || exit_code=$?

  assert_general_error "" "" "$exit_code"
  # One attributed error line per failing file (the message repeats in the
  # deferred failure blocks, so count the normalized progress lines).
  assert_equals "2" "$(printf '%s\n' "$output" | grep -c "Set up before script")"
  assert_contains "Later file still runs" "$output"
  assert_contains "1 passed" "$output"
  assert_contains "4 failed" "$output"
  assert_contains "5 total" "$output"
}

function test_hook_failure_counts_match_in_parallel() {
  local output
  local exit_code=0
  output=$(./bashunit --parallel --detailed --skip-env-file \
    "$FIXTURES/plain_hook.sh" "$FIXTURES/guard_hook.sh" "$FIXTURES/later.sh" 2>&1) || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_contains "1 passed" "$output"
  assert_contains "4 failed" "$output"
  assert_contains "5 total" "$output"
}

# Writes a throwaway test file whose `set_up` runs $1 (a failing assertion) and
# echoes its path.
#
# The file is assembled with printf, not a heredoc, on purpose: bashunit's own
# duplicate-test-function scan reads *this* file as text, and a literal
# `function test_...() {` line sitting inside a heredoc here would be counted as
# a test function defined twice in this file.
function _write_failing_hook_fixture() {
  local hook_body="$1"
  local name="$2"
  local kw="function"
  local dir
  dir="$(bashunit::temp_dir)"

  {
    printf '#!/usr/bin/env bash\n\n'
    printf '%s set_up() {\n  %s\n}\n\n' "$kw" "$hook_body"
    printf '%s test_placeholder() {\n  assert_same "1" "1"\n}\n' "$kw"
  } >"$dir/$name"

  echo "$dir/$name"
}

# An assertion that fails inside `set_up` runs with no `test_*` frame on the
# call stack, so its label falls back to `FUNCNAME[$fallback_depth]` -- the
# assertion function's own name. That makes the label sensitive to how many
# frames sit between the assertion and the label resolver, so any helper
# factored out of the assertion bodies has to compensate for the frame it adds.
# Nothing else pins this: the `-a` standalone path sets a custom title, which
# short-circuits the fallback entirely.
function test_assertion_failing_in_a_hook_is_labelled_with_its_own_name() {
  local fixture
  fixture="$(_write_failing_hook_fixture \
    'assert_same "expected-from-hook" "actual-from-hook"' "label_fallback_test.sh")"

  local output
  local exit_code=0
  output=$(./bashunit --no-parallel --detailed --no-color --skip-env-file \
    "$fixture" 2>&1) || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_contains "Failed: Assert same" "$output"
  assert_contains "expected-from-hook" "$output"
}

# Companion to the above for a multi-branch assertion: assert_arrays_equal used
# to resolve its label through the echoing `bashunit::assert::label` wrapper,
# whose extra frame made the fallback report the wrapper's own name
# ("Bashunit::assert::label") instead of the assertion's.
function test_array_assertion_failing_in_a_hook_is_labelled_with_its_own_name() {
  local fixture
  fixture="$(_write_failing_hook_fixture \
    'assert_arrays_equal "a" -- "b"' "array_label_fallback_test.sh")"

  local output
  local exit_code=0
  output=$(./bashunit --no-parallel --detailed --no-color --skip-env-file \
    "$fixture" 2>&1) || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_contains "Failed: Assert arrays equal" "$output"
  assert_not_contains "Bashunit::assert::label" "$output"
}
