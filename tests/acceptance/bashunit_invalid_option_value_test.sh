#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_FILE="tests/acceptance/fixtures/tests_path/a_test.sh"
}

# The numeric options used to accept any string. `[ n -lt abc ]` errors rather
# than returning false, so the value was either ignored or -- on the Bash 3.x
# job-slot poll -- looped forever (#873).
function test_bashunit_fails_when_jobs_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--jobs" "$output"
}

function test_bashunit_fails_when_jobs_is_negative() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs -5 "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
}

function test_bashunit_fails_when_retry_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --retry abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--retry" "$output"
}

function test_bashunit_fails_when_test_timeout_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --test-timeout abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--test-timeout" "$output"
}

function test_bashunit_fails_when_coverage_min_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --coverage-min abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--coverage-min" "$output"
}

function test_bashunit_fails_when_output_format_is_unsupported() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --output nonsense "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--output" "$output"
}

# The environment path bypasses flag parsing entirely, so it needs the same gate.
function test_bashunit_fails_when_parallel_jobs_env_var_is_not_a_number() {
  local ec=0
  local output
  output=$(BASHUNIT_PARALLEL_JOBS=abc ./bashunit --env "$TEST_ENV_FILE" --parallel "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_PARALLEL_JOBS" "$output"
}

# BASHUNIT_COVERAGE_THRESHOLD_LOW/HIGH are env-only (no CLI flag) and are
# compared with `[ -ge ]` in bashunit::coverage::get_coverage_class. A
# non-integer value used to leak a raw "integer expression expected" shell
# error into the coverage report and silently mis-bucket every file's
# high/medium/low class instead of failing fast (#879).
function test_bashunit_fails_when_coverage_threshold_high_env_var_is_not_a_number() {
  local ec=0
  local output
  # .env / .env.example both list this name with an empty value. That used to
  # override the exported value and this test needed --skip-env-file to work;
  # since #865 an empty entry no longer clobbers the caller, so the real path is
  # exercised here.
  output=$(BASHUNIT_COVERAGE_THRESHOLD_HIGH=abc ./bashunit --coverage "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_COVERAGE_THRESHOLD_HIGH" "$output"
}

function test_bashunit_fails_when_coverage_threshold_low_env_var_is_not_a_number() {
  local ec=0
  local output
  # See the note above.
  output=$(BASHUNIT_COVERAGE_THRESHOLD_LOW=abc ./bashunit --coverage "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_COVERAGE_THRESHOLD_LOW" "$output"
}

function test_bashunit_still_accepts_valid_option_values() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs 2 --retry 0 --test-timeout 0 "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}

function test_bashunit_still_accepts_jobs_auto() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs auto "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}

function test_bashunit_still_accepts_tap_output() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --output tap "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "TAP version 13" "$output"
}

# `--coverage-report` is documented with the page's optional notation
# (`[file]`), and --coverage-report-html already defaults its value. Omitting the
# value used to abort the run with `$2: unbound variable` before any test ran,
# and a following flag was consumed as the filename.
function test_coverage_report_without_a_value_uses_the_default_path() {
  local dir output
  dir="$(bashunit::temp_dir)"

  # The path goes first: an optional value cannot be told apart from a test path,
  # which is why --coverage-diff requires its ref (src/main/test.sh).
  output=$(cd "$dir" && "$OLDPWD/bashunit" --env "$OLDPWD/$TEST_ENV_FILE" \
    "$OLDPWD/$TEST_FILE" --coverage --coverage-report 2>&1) || true

  assert_not_contains "unbound variable" "$output"
  assert_file_exists "$dir/coverage/lcov.info"
}

function test_coverage_report_does_not_swallow_the_next_flag_as_its_value() {
  local dir output
  dir="$(bashunit::temp_dir)"

  output=$(cd "$dir" && "$OLDPWD/bashunit" --env "$OLDPWD/$TEST_ENV_FILE" \
    --coverage --coverage-report --no-color "$OLDPWD/$TEST_FILE" 2>&1) || true

  assert_not_contains "unbound variable" "$output"
  assert_not_contains "No such file or directory" "$output"
  assert_file_exists "$dir/coverage/lcov.info"
}

function test_bashunit_debug_without_a_file_runs_the_test_path() {
  local dir before output ec=0
  dir="$(bashunit::temp_dir)"
  printf 'function test_debug_existing_file() { assert_same 1 1; }\n' >"$dir/sample_test.sh"
  before="$(cksum <"$dir/sample_test.sh")"
  output="$dir/output.log"

  BASHUNIT_DEFAULT_PATH="$dir" ./bashunit --skip-env-file --no-color \
    --debug "$dir/sample_test.sh" >"$output" 2>&1 || ec=$?

  assert_same "$before" "$(cksum <"$dir/sample_test.sh")"
  assert_successful_code "" "" "$ec"
  assert_file_contains "$output" "1 passed"
}

function test_bashunit_debug_without_a_file_runs_the_test_directory() {
  local dir output ec=0
  dir="$(bashunit::temp_dir)"
  printf 'function test_debug_existing_directory() { assert_same 1 1; }\n' >"$dir/sample_test.sh"
  output="$dir/output.log"

  BASHUNIT_DEFAULT_PATH="$dir" ./bashunit --skip-env-file --no-color --debug "$dir" >"$output" 2>&1 || ec=$?

  assert_successful_code "" "" "$ec"
  assert_file_contains "$output" "1 passed"
  assert_file_not_contains "$output" "Is a directory"
}

function test_bashunit_debug_writes_to_a_new_trace_file() {
  local dir ec=0
  dir="$(bashunit::temp_dir)"
  printf 'function test_debug_new_trace_file() { assert_same 1 1; }\n' >"$dir/sample_test.sh"

  ./bashunit --skip-env-file --no-color --debug "$dir/trace.log" "$dir/sample_test.sh" >/dev/null 2>&1 || ec=$?

  assert_successful_code "" "" "$ec"
  assert_file_exists "$dir/trace.log"
  assert_file_contains "$dir/trace.log" "1 passed"
  assert_file_contains "$dir/trace.log" "+ "
}

function test_bashunit_debug_as_the_last_argument_keeps_tracing_to_the_terminal() {
  local dir output ec=0
  dir="$(bashunit::temp_dir)"
  printf 'function test_debug_last_argument() { assert_same 1 1; }\n' >"$dir/sample_test.sh"
  output="$dir/output.log"

  ./bashunit --skip-env-file --no-color "$dir/sample_test.sh" --debug >"$output" 2>&1 || ec=$?

  assert_successful_code "" "" "$ec"
  assert_file_contains "$output" "1 passed"
  assert_file_contains "$output" "+ "
}
