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

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --tag nonexistent "$test_file" 2>&1)

  assert_contains "0 total" "$output"
}
