#!/usr/bin/env bash
# shellcheck disable=SC2016 # fixture lines are written literally, not expanded
set -euo pipefail

# The "at <file>:<line>" footer names the line in the test body that led to the
# failure, not the line that defines the test. An assertion inside a helper adds
# "in <helper> at <file>:<line>". The "N) file:line" header keeps the definition
# line, which reports and editors already depend on.

function _write_location_fixture() {
  local file=$1
  shift
  printf '%s\n' "$@" >"$file"
}

function test_failure_location_names_the_helper_call_line() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/helper.sh"
  _write_location_fixture "$file" \
    'function helper() { assert_equals 1 2; }' \
    'function test_through_helper() {' \
    '  helper' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:3" "$output"
  assert_contains "    in helper at $file:1" "$output"
  assert_not_contains "at $file:2" "$output"
}

function test_failure_location_is_the_same_under_parallel() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/helper_parallel.sh"
  _write_location_fixture "$file" \
    'function helper_parallel() { assert_equals 1 2; }' \
    'function test_through_helper_in_parallel() {' \
    '  helper_parallel' \
    '}'

  output="$(./bashunit --skip-env-file --parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:3" "$output"
  assert_contains "    in helper_parallel at $file:1" "$output"
}

function test_failure_location_names_a_direct_assertion_line() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/direct.sh"
  _write_location_fixture "$file" \
    '#!/usr/bin/env bash' \
    'function test_direct_assertion() {' \
    '  local value=2' \
    '  assert_equals 1 "$value"' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:4" "$output"
  assert_not_contains "    in " "$output"
}

function test_failure_location_header_keeps_the_definition_line() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/header.sh"
  _write_location_fixture "$file" \
    'function test_header_definition() {' \
    '  assert_equals 1 2' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "1) $file:1" "$output"
  assert_contains "    at $file:2" "$output"
}

function test_failure_location_treats_a_custom_assertion_as_the_assertion() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/custom.sh"
  _write_location_fixture "$file" \
    'function assert_positive() {' \
    '  bashunit::assertion_failed "positive" "$1"' \
    '}' \
    'function test_custom_assertion() {' \
    '  assert_positive -1' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:5" "$output"
  assert_not_contains "    in " "$output"
}

function test_failure_location_names_a_helper_that_calls_bashunit_fail() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/fail.sh"
  _write_location_fixture "$file" \
    'function check_ready() {' \
    '  bashunit::fail "not ready"' \
    '}' \
    'function test_fail_through_helper() {' \
    '  check_ready' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:5" "$output"
  assert_contains "    in check_ready at $file:2" "$output"
}

function test_failure_location_falls_back_to_the_definition_for_runtime_errors() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/runtime.sh"
  _write_location_fixture "$file" \
    'function test_runtime_error() {' \
    '  no_such_command_for_location' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "✗ Error" "$output"
  assert_contains "    at $file:1" "$output"
}

function test_failure_location_of_assert_once_names_the_failing_call_not_the_flush() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/once.sh"
  _write_location_fixture "$file" \
    'function assert_user() { bashunit::assert_once; assert_equals 1 "$1"; }' \
    'function test_once_custom_assertion() {' \
    '  assert_user 2' \
    '  assert_equals 1 1' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:3" "$output"
  assert_not_contains "at $file:4" "$output"
}

function test_failure_location_of_assert_once_in_a_loop_names_the_failing_iteration() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/once_loop.sh"
  _write_location_fixture "$file" \
    'function check_user() {' \
    '  bashunit::assert_once' \
    '  assert_equals 1 "$1"' \
    '}' \
    'function test_once_helper_loop() {' \
    '  local i' \
    '  for i in 1 2 1; do check_user "$i"; done' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:7" "$output"
  assert_contains "    in check_user at $file:3" "$output"
  assert_not_contains "in check_user at $file:2" "$output"
}

function test_failure_location_of_assert_once_survives_an_assertion_capture() {
  local dir file output
  dir="$(bashunit::temp_dir)"
  file="$dir/once_capture.sh"
  _write_location_fixture "$file" \
    'function check_location_capture() {' \
    '  bashunit::assert_once' \
    '  assert_equals 1 2' \
    '  assert_assertion_fails assert_equals 1 2' \
    '}' \
    'function test_once_location_capture() {' \
    '  check_location_capture' \
    '  assert_equals 1 1' \
    '}'

  output="$(./bashunit --skip-env-file --no-parallel --no-color "$file" 2>&1 || true)"

  assert_contains "    at $file:7" "$output"
  assert_contains "    in check_location_capture at $file:3" "$output"
  assert_not_contains "at $file:8" "$output"
}
