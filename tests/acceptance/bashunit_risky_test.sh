#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_bashunit_risky_test_shows_warning() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

  local actual_raw
  actual_raw="$(BASHUNIT_STRICT_MODE=false ./bashunit \
    --no-parallel --detailed --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "Risky" "$actual"
  assert_contains "1 risky" "$actual"
}

function test_bashunit_risky_test_does_not_fail() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

  local actual_raw
  actual_raw="$(BASHUNIT_STRICT_MODE=false ./bashunit \
    --no-parallel --simple --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "risky" "$actual"
  assert_not_contains "failed" "$actual"
}

function test_bashunit_fail_on_risky_flag_makes_risky_fail() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

  local actual_raw
  set +e
  actual_raw="$(BASHUNIT_STRICT_MODE=false ./bashunit \
    --no-parallel --fail-on-risky --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "1 failed" "$actual"
  assert_not_contains "1 risky" "$actual"
  assert_general_error "$(BASHUNIT_STRICT_MODE=false ./bashunit \
    --no-parallel --fail-on-risky --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_fail_on_risky_env_var_makes_risky_fail() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

  local actual_raw
  set +e
  actual_raw="$(BASHUNIT_STRICT_MODE=false BASHUNIT_FAIL_ON_RISKY=true ./bashunit \
    --no-parallel --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "1 failed" "$actual"
}

function test_bashunit_fail_on_risky_works_in_parallel() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

  local actual_raw
  set +e
  actual_raw="$(BASHUNIT_STRICT_MODE=false ./bashunit \
    --parallel --fail-on-risky --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "1 failed" "$actual"
}
