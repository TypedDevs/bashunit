#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_FILE="tests/acceptance/fixtures/tests_path/a_test.sh"
}

# An unmatched option used to fall through to the test-path list, so the run
# continued with the flag silently ignored and still exited 0 (#871).
function test_bashunit_fails_when_given_an_unknown_option() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --parralel "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--parralel" "$output"
}

function test_bashunit_reports_an_unknown_option_before_running_any_test() {
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --parralel "$TEST_FILE" 2>&1 || true)

  assert_not_contains "All tests passed" "$output"
}

# The value of a mistyped value-taking flag must not be mistaken for a test path.
function test_bashunit_fails_when_given_an_unknown_option_that_takes_a_value() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --filterr nope "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--filterr" "$output"
}

function test_bashunit_still_accepts_a_known_option_with_a_path() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}

function test_bashunit_bench_fails_when_given_an_unknown_option() {
  local bench_dir
  bench_dir="$(bashunit::temp_dir)"
  printf '#!/usr/bin/env bash\nfunction bench_sample() { :; }\n' >"$bench_dir/sample_bench.sh"

  local ec=0
  local output
  output=$(./bashunit bench --nonsense-flag "$bench_dir" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--nonsense-flag" "$output"
}

function test_bashunit_still_accepts_a_bare_path() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}
