#!/usr/bin/env bash

# bashunit::skip marks a test skipped but does not stop it, so every call site
# had to remember `&& return`. The conditional helpers below do both.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_conditional_skip.sh"
  OS_FIXTURE="tests/acceptance/fixtures/test_bashunit_skip_on.sh"
}

function run_fixture() { # $1 = extra flags, $2 = fixture
  # shellcheck disable=SC2086
  NO_COLOR=1 ./bashunit $1 --env "$TEST_ENV_FILE" "${2:-$FIXTURE}" 2>&1 || true
}

function test_skip_if_marks_the_test_skipped_and_stops_the_body() {
  local output
  output=$(run_fixture "--no-parallel")

  assert_contains "Skipped: Skip if true stops the body" "$output"
  assert_contains "condition met" "$output"
  assert_not_contains "unreachable" "$output"
}

function test_skip_if_lets_the_body_run_when_the_condition_is_false() {
  local output
  output=$(run_fixture "--no-parallel")

  assert_not_contains "never used" "$output"
  assert_contains "Passed: Skip if false runs the body" "$output"
}

function test_skip_unless_command_names_the_missing_command() {
  local output
  output=$(run_fixture "--no-parallel")

  assert_contains "requires definitely_not_a_command" "$output"
  assert_contains "Passed: Skip unless command present" "$output"
}

function test_every_skipped_test_is_counted_once() {
  local output
  output=$(run_fixture "--no-parallel")

  # 6 skipped: skip_if true, skip_if compound, skip_unless false,
  # skip_unless_command missing and the two data-provider cases.
  assert_contains "6 skipped" "$output"
  assert_contains "3 passed" "$output"
}

function test_the_counts_are_the_same_under_parallel() {
  local sequential parallel
  sequential=$(run_fixture "--no-parallel" | "$GREP" -c "Skipped:")
  parallel=$(run_fixture "--parallel" | "$GREP" -c "Skipped:")

  assert_same "$sequential" "$parallel"
}

function test_skip_on_skips_only_the_running_os() {
  local output
  output=$(run_fixture "--no-parallel" "$OS_FIXTURE")

  assert_contains "Skipped: Skip on the current os" "$output"
  assert_contains "not for this os" "$output"
  assert_contains "Passed: Skip on another os runs the body" "$output"
}

function test_skip_on_an_unknown_os_is_a_usage_error() {
  local output
  output=$(run_fixture "--no-parallel" "$OS_FIXTURE")

  assert_contains "Error: Skip on an unknown os" "$output"
  assert_contains "windows, macos or linux" "$output"
}

function test_reports_carry_the_skipped_tests() {
  local report
  report="$(bashunit::temp_file)"
  NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --report-junit "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_contains 'skipped="6"' "$(cat "$report")"
  assert_contains "condition met" "$(cat "$report")"
}
