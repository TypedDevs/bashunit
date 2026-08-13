#!/usr/bin/env bash
set -euo pipefail

# Sequential and --parallel must reach the same verdict for the same file.
#
# State set inside call_test_functions dies with the background worker
# --parallel spawns; only .result payloads cross that fork. Duplicate-test
# detection was therefore entirely off under --parallel while the sequential
# run rejected the same file (#1147), and the reporting added for an unusable
# data provider counted in one mode and not the other until it wrote a .result
# too (#1145). Neither is visible to a sequential test.
#
# So compare the two modes directly, over the outcome shapes a run can produce.
# A new check that only works in one mode fails here instead of in the field.
#
# Verified against both regressions: restoring the pre-#1147 placement of the
# duplicate check fails the duplicate case, and dropping the .result write from
# report_unusable_provider fails the provider case. Note that the original
# #1145 -- the test vanishing outright -- was NOT a parity bug: both modes
# dropped it identically, and this file passes on that code. Parity catches the
# half of a fix that forgets the fork; bashunit_provider_missing_test.sh is
# what holds the behaviour itself.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  PARITY_DIR="$(bashunit::temp_dir)"
}

# Writes a fixture and returns its path.
#
# Every function name below is unique across the whole file, including the ones
# that only ever exist inside these quoted bodies: the duplicate check scans a
# file textually, so a name reused in two fixtures reads as *this* file
# defining it twice and fails the run before any test executes.
function parity_fixture() { # $1 = name, $2 = body
  local fixture="$PARITY_DIR/$1.sh"
  printf '%s\n%s\n' '#!/usr/bin/env bash' "$2" >"$fixture"
  printf '%s' "$fixture"
}

# The run's verdict: the totals line plus the exit code, with the colouring and
# the parallel spinner's carriage returns removed. Everything else (ordering,
# per-test lines, timing) legitimately differs between the modes.
function verdict() { # $1 = mode flag, $2 = fixture
  local out code=0
  out="$(./bashunit "$1" --env "$TEST_ENV_FILE" "$2" 2>&1)" || code=$?

  local totals
  totals="$(printf '%s' "$out" | strip_ansi | tr -d '\r' \
    | grep -E "Tests:[[:space:]]+[0-9]" | tail -1 | tr -s ' ')"

  printf 'exit=%s %s' "$code" "${totals# }"
}

function assert_modes_agree() { # $1 = name, $2 = body
  local fixture
  fixture="$(parity_fixture "$1" "$2")"

  local sequential parallel
  sequential="$(verdict --no-parallel "$fixture")"
  parallel="$(verdict --parallel "$fixture")"

  assert_same "$sequential" "$parallel"
}

function test_a_failing_assertion_agrees() {
  assert_modes_agree failing 'function test_bad() { assert_same 1 2; }
function test_good_1() { assert_same 1 1; }'
}

function test_a_runtime_error_agrees() {
  assert_modes_agree runtime_error 'function test_boom() { no_such_command_xyz; }
function test_good_2() { assert_same 1 1; }'
}

function test_a_nonzero_exit_inside_a_test_agrees() {
  assert_modes_agree exit_code 'function test_exits() { assert_same 1 1; exit 7; }'
}

function test_a_failing_set_up_agrees() {
  assert_modes_agree setup_fail 'function set_up() { return 3; }
function test_any_3() { assert_same 1 1; }'
}

function test_a_failing_tear_down_agrees() {
  assert_modes_agree teardown_fail 'function tear_down() { return 3; }
function test_any_4() { assert_same 1 1; }'
}

function test_a_failing_set_up_before_script_agrees() {
  assert_modes_agree sbs_fail 'function set_up_before_script() { return 3; }
function test_any_5() { assert_same 1 1; }'
}

function test_a_syntax_error_agrees() {
  assert_modes_agree syntax_error 'function test_any_6() { assert_same 1 1; }
function broken( {'
}

function test_a_risky_test_agrees() {
  assert_modes_agree risky 'function test_no_assertions() { local x=1; }'
}

function test_skipped_and_incomplete_agree() {
  assert_modes_agree skip_todo 'function test_skipped() { bashunit::skip "why"; }
function test_todo() { bashunit::todo "later"; }'
}

# The two that were actually broken.
function test_an_unusable_data_provider_agrees() {
  assert_modes_agree provider_missing '# @data_provider provider_gone
function test_needs_data() { assert_same "a" "$1"; }
function test_good_7() { assert_same 1 1; }'
}

function test_a_duplicate_test_function_agrees() {
  local fixture="$PARITY_DIR/duplicate.sh"
  printf '%s\n' '#!/usr/bin/env bash' >"$fixture"
  printf 'function %s() { assert_same 1 1; }\n' test_twin >>"$fixture"
  printf 'function %s() { assert_same 2 2; }\n' test_twin >>"$fixture"

  assert_same "$(verdict --no-parallel "$fixture")" "$(verdict --parallel "$fixture")"
}
