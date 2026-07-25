#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_FILE="tests/acceptance/fixtures/tests_path/a_test.sh"
}

# A missing bootstrap used to leak a raw `source` error, run no tests at all and
# still exit 0 -- a green build that tested nothing (#875).
function test_bashunit_fails_when_the_bootstrap_file_is_missing() {
  local ec=0
  local output
  output=$(./bashunit --env definitely_missing_bootstrap.sh "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "definitely_missing_bootstrap.sh" "$output"
}

function test_bashunit_fails_when_the_bootstrap_file_is_missing_via_boot_alias() {
  local ec=0
  local output
  output=$(./bashunit --boot definitely_missing_bootstrap.sh "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
}

# The report was silently not written while the suite still reported success, so
# a CI job uploaded an empty artifact from a green build.
function test_bashunit_fails_when_a_report_path_is_not_writable() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --report-json /nope/dir/out.json "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "/nope/dir/out.json" "$output"
}

function test_bashunit_fails_when_a_junit_report_path_is_not_writable() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --log-junit /nope/dir/out.xml "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
}

function test_bashunit_fails_when_seed_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --seed abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--seed" "$output"
}

function test_bashunit_still_accepts_an_existing_bootstrap_file() {
  local boot_file
  boot_file="$(bashunit::temp_file)"
  printf 'export BASHUNIT_TEST_BOOTSTRAP_MARKER=loaded\n' >"$boot_file"

  local ec=0
  local output
  output=$(./bashunit --env "$boot_file" "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}

function test_bashunit_still_writes_a_report_to_a_writable_path() {
  local report_dir
  report_dir="$(bashunit::temp_dir)"

  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --report-json "$report_dir/out.json" "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_file_exists "$report_dir/out.json"
}
