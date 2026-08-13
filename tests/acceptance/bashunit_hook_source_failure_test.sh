#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_tear_down_sources_nonexistent_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_sources_nonexistent_file.sh

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_set_up_before_script_sources_nonexistent_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_setup_before_script_sources_nonexistent_file.sh

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_tear_down_after_script_sources_nonexistent_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_after_script_sources_nonexistent_file.sh

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

# A file that fails to source without writing anything to stderr used to report
# only "Failed to source 'x' (exit N)", which cannot distinguish a truncated
# file from one whose last command simply returned non-zero -- the difference
# that matters when it only happens on loaded CI (#1137).
function test_a_silent_source_failure_reports_the_file_size() {
  local fixture
  fixture="$(bashunit::temp_file silent_source).sh"
  printf 'function test_x() { assert_same 1 1; }\nfalse\n' >"$fixture"

  local actual
  set +e
  actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1)"
  set -e

  assert_contains "no stderr" "$(printf '%s' "$actual" | strip_ansi)"
  assert_contains "bytes" "$(printf '%s' "$actual" | strip_ansi)"
}
