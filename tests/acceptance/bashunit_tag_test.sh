#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_tag_runs_only_matching_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag slow "$test_file" 2>&1)

  assert_contains "2 passed" "$output"
  assert_contains "2 total" "$output"
}

function test_tag_fast_runs_only_fast_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag fast "$test_file" 2>&1)

  assert_contains "1 passed" "$output"
  assert_contains "1 total" "$output"
}

function test_tag_database_runs_only_database_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag database "$test_file" 2>&1)

  assert_contains "1 passed" "$output"
  assert_contains "1 total" "$output"
}

function test_exclude_tag_skips_matching_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --exclude-tag slow "$test_file" 2>&1)

  assert_contains "2 passed" "$output"
  assert_contains "2 total" "$output"
}

function test_exclude_tag_takes_precedence_over_tag() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag slow --exclude-tag database "$test_file" 2>&1)

  assert_contains "1 passed" "$output"
  assert_contains "1 total" "$output"
}

function test_multiple_tags_use_or_logic() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag slow --tag fast "$test_file" 2>&1)

  assert_contains "3 passed" "$output"
  assert_contains "3 total" "$output"
}

function test_no_tag_flags_runs_all_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" 2>&1)

  assert_contains "4 passed" "$output"
  assert_contains "4 total" "$output"
}

function test_tag_nonexistent_runs_zero_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag nonexistent "$test_file" 2>&1) || true

  assert_contains "0 total" "$output"
}

# Tag expressions and file-level tags (#1008). Selection is asserted through
# --list rather than by parsing run output: it is the same filtering pipeline
# and the comparison is exact.
TAGS_FIXTURE=./tests/acceptance/fixtures/test_bashunit_with_tags.sh
FILE_TAGS_FIXTURE=./tests/acceptance/fixtures/file_tags_fixture.sh

function test_and_expression_selects_only_tests_with_both_tags() {
  local output
  output=$(./bashunit --list --tag 'slow&&database' "$TAGS_FIXTURE" 2>/dev/null)

  assert_same "$TAGS_FIXTURE::test_slow_database_query" "$output"
}

function test_negation_expression_excludes_the_tag() {
  local output
  output=$(./bashunit --list --tag '!slow' "$TAGS_FIXTURE" 2>/dev/null)

  assert_same "\
$TAGS_FIXTURE::test_fast_operation
$TAGS_FIXTURE::test_no_tags" "$output"
}

function test_and_with_negation_expression() {
  local output
  output=$(./bashunit --list --tag 'slow&&!database' "$TAGS_FIXTURE" 2>/dev/null)

  assert_same "$TAGS_FIXTURE::test_slow_operation" "$output"
}

# Back-compat: repeated --tag flags stay OR.
function test_repeated_tag_flags_still_use_or_logic() {
  local output
  output=$(./bashunit --list --tag fast --tag database "$TAGS_FIXTURE" 2>/dev/null)

  assert_same "\
$TAGS_FIXTURE::test_fast_operation
$TAGS_FIXTURE::test_slow_database_query" "$output"
}

function test_exclude_tag_still_wins_over_an_expression() {
  local output
  output=$(./bashunit --list --tag 'slow&&database' --exclude-tag database "$TAGS_FIXTURE" 2>/dev/null)

  assert_empty "$output"
}

function test_file_level_tags_select_every_test_in_the_file() {
  local output
  output=$(./bashunit --list --tag integration "$FILE_TAGS_FIXTURE" 2>/dev/null)

  assert_same "\
$FILE_TAGS_FIXTURE::test_inherits_file_tags
$FILE_TAGS_FIXTURE::test_inherits_and_adds" "$output"
}

function test_file_level_and_function_tags_combine_in_an_expression() {
  local output
  output=$(./bashunit --list --tag 'db&&slow' "$FILE_TAGS_FIXTURE" 2>/dev/null)

  assert_same "$FILE_TAGS_FIXTURE::test_inherits_and_adds" "$output"
}

function test_a_malformed_tag_expression_exits_non_zero() {
  local exit_code=0
  ./bashunit --list --tag 'slow&&' "$TAGS_FIXTURE" >/dev/null 2>&1 || exit_code=$?

  assert_equals 1 "$exit_code"
}

function test_a_malformed_tag_expression_explains_itself() {
  local output
  output=$(./bashunit --list --tag '!' "$TAGS_FIXTURE" 2>&1) || true

  assert_contains "invalid tag expression" "$output"
}

# The whole point of rejecting it: a malformed expression must not quietly
# behave like "no filter" and run the entire suite.
function test_a_malformed_tag_expression_does_not_select_everything() {
  local output
  output=$(./bashunit --list --tag '&&' "$TAGS_FIXTURE" 2>/dev/null) || true

  assert_empty "$output"
}

# A trailing separator is the case that reads as valid: `slow&&` used to be
# accepted and silently evaluated as plain `slow`.
function test_a_trailing_separator_is_rejected_rather_than_narrowed() {
  local output
  output=$(./bashunit --list --tag 'slow&&' "$TAGS_FIXTURE" 2>/dev/null) || true

  assert_empty "$output"
}
