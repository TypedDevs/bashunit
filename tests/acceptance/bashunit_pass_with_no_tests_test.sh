#!/usr/bin/env bash
set -euo pipefail

# An empty selection exits non-zero, which is what jest, vitest, pytest, go
# test, deno and node all do -- and it is right for the common case, where
# selecting nothing means a typo. It is wrong for the deliberate one: a CI
# matrix that shards a suite has shards with no tests in them, and that is not
# a failure.
#
# jest and vitest solved this with the same flag under the same name, so this
# reuses it rather than inventing a third spelling; PHPUnit ships both
# polarities (--fail-on-empty-test-suite / --do-not-fail-on-empty-test-suite).
# Kebab-case to match the rest of bashunit's long flags.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir pass_with_no_tests)"
  mkdir -p "$WORKDIR/empty_dir"
}

function test_an_empty_selection_still_fails_by_default() {
  local ec=0
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --env "$TEST_ENV_FILE" "$WORKDIR/empty_dir" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "No tests found" "$output"
}

function test_pass_with_no_tests_makes_an_empty_selection_succeed() {
  local ec=0
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --env "$TEST_ENV_FILE" \
    --pass-with-no-tests "$WORKDIR/empty_dir" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  # Still says what happened: the flag changes the verdict, not the report.
  assert_contains "No tests found" "$output"
}

# The empty-shard case the flag exists for.
function test_pass_with_no_tests_covers_an_empty_shard() {
  local ec=0
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --env "$TEST_ENV_FILE" --pass-with-no-tests \
    --shard 4/4 tests/acceptance/fixtures/tests_path/a_test.sh 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
}

function test_pass_with_no_tests_covers_a_filter_matching_nothing() {
  local ec=0
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --env "$TEST_ENV_FILE" --pass-with-no-tests \
    --filter definitely_no_such_test tests/acceptance/fixtures/tests_path 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
}

# The line between the two answers has to hold: a path that is not on disk is a
# wrong invocation, not an empty selection, so this flag must not launder a
# typo into a green run. jest cannot draw that line because its arguments are
# patterns; bashunit takes paths, so it can.
function test_pass_with_no_tests_does_not_excuse_a_missing_path() {
  local ec=0
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --env "$TEST_ENV_FILE" \
    --pass-with-no-tests "$WORKDIR/definitely_not_here" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "no such path" "$output"
}

# A real failure still fails: the flag is about an empty run, nothing else.
function test_pass_with_no_tests_does_not_hide_a_failing_test() {
  printf 'function test_nope() { assert_same 1 2; }\n' >"$WORKDIR/f_test.sh"

  local ec=0
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --env "$TEST_ENV_FILE" \
    --pass-with-no-tests "$WORKDIR/f_test.sh" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "1 failed" "$output"
}
