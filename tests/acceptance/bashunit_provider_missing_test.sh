#!/usr/bin/env bash
set -euo pipefail

# A @data_provider that names a function which is not defined -- a typo, or a
# provider that moved -- yielded no data sets, so the runner's per-data-set loop
# body never ran and the test disappeared from the run entirely. The summary
# then said "No tests found", diagnosing a missing *test* when what was missing
# was the *provider*, and the name of the annotation was never printed (#1145).

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function run_fixture() { # $1 = file contents
  local fixture
  fixture="$(bashunit::temp_file provider_missing).sh"
  printf '%s\n' "$1" >"$fixture"

  local actual
  set +e
  actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1)"
  set -e

  printf '%s' "$actual" | strip_ansi
}

function test_an_undefined_data_provider_names_itself() {
  local actual
  actual="$(run_fixture '# @data_provider provider_typo
function test_undefined() { assert_same "a" "$1"; }')"

  assert_contains "provider_typo" "$actual"
  assert_not_contains "No tests found" "$actual"
}

function test_an_undefined_data_provider_still_fails_the_run() {
  local fixture
  fixture="$(bashunit::temp_file provider_missing_code).sh"
  printf '%s\n' '# @data_provider provider_typo
function test_undefined_code() { assert_same "a" "$1"; }' >"$fixture"

  # Under --strict the suite runs with `set -e`, so the non-zero exit under
  # test would abort this function before the assertion ever ran.
  local code=0
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$fixture" >/dev/null 2>&1 || code=$?

  # The code goes in $3: assert_general_error reads ${3-"$?"}, and after the
  # `|| code=$?` above `$?` is the assignment's own zero.
  assert_general_error "" "" "$code"
}

# A provider that is defined but yields nothing drops the test the same way,
# and is the harder one to spot: the name resolves, so nothing looks wrong.
function test_a_data_provider_that_yields_no_data_says_so() {
  local actual
  actual="$(run_fixture 'function provider_empty() { :; }
# @data_provider provider_empty
function test_empty() { assert_same "a" "$1"; }')"

  assert_contains "provider_empty" "$actual"
  assert_not_contains "No tests found" "$actual"
}

# Under --parallel the whole per-file loop runs in a background subshell, so a
# counter incremented there dies with it and only .result files reach the
# aggregate. A run that printed the error and still exited 0 is the worst shape
# this bug can take: CI goes green with the reason on screen.
function test_the_failure_survives_parallel_aggregation() {
  local fixture
  fixture="$(bashunit::temp_file provider_missing_parallel).sh"
  printf '%s\n' 'function test_ok() { assert_same 1 1; }
# @data_provider nope
function test_broken() { assert_same "a" "$1"; }' >"$fixture"

  local actual
  set +e
  actual="$(./bashunit --parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1)"
  local code=$?
  set -e

  assert_same 1 "$code"
  assert_contains "1 failed" "$(printf '%s' "$actual" | strip_ansi)"
}

# The working path must stay untouched: a provider with data still runs once
# per data set and reports nothing extra.
function test_a_working_data_provider_is_unaffected() {
  local actual
  actual="$(run_fixture 'function provider_ok() { echo "a"; echo "a"; }
# @data_provider provider_ok
function test_ok_data() { assert_same "a" "$1"; }')"

  assert_contains "2 passed" "$actual"
  assert_not_contains "data provider" "$actual"
}
