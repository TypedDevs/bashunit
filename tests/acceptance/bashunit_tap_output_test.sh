#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_tap_output_passing_tests_matches_snapshot() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file")"
}

function test_tap_output_failing_tests_matches_snapshot() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file" 2>&1 || true)"
}

function test_tap_output_env_var_equivalent_to_flag() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local via_flag
  local via_env

  via_flag=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file")
  via_env=$(BASHUNIT_OUTPUT_FORMAT=tap ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")

  assert_equals "$via_flag" "$via_env"
}

function test_tap_output_exits_non_zero_on_failure() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file" 2>&1)"
}

# TAP 13 reads an unescaped `#` on a test line as the start of a directive, so a
# title holding one hands the consumer a directive bashunit never meant. The
# dangerous direction is a FAILING test titled "... # SKIP ...": every consumer
# reads `not ok` with a SKIP directive as not-a-failure, and the failure leaves
# CI silently.
#
# `--report-tap` has escaped this since #1119; the `--output tap` stream, which
# a different emitter writes, never did.
function test_output_tap_escapes_a_hash_in_the_description() {
  local dir
  dir="$(bashunit::temp_dir tap_hash)"
  {
    printf 'function test_titled() {\n'
    printf '  bashunit::set_test_title "validates input # SKIP unsupported"\n'
    printf '  assert_same "expected" "actual"\n'
    printf '}\n'
  } >"$dir/hash_test.sh"

  local output
  output=$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --output tap "$dir/hash_test.sh" 2>/dev/null) || true

  local line
  line=$(printf '%s\n' "$output" | grep -E '^not ok' | head -1)

  assert_contains '\#' "$line"
  assert_not_contains ' # SKIP' "$line"
}
