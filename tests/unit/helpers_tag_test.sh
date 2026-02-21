#!/usr/bin/env bash
# shellcheck disable=SC2317

function test_get_tags_for_function_returns_tags() {
  local script="tests/acceptance/fixtures/test_bashunit_with_tags.sh"
  local result
  result=$(bashunit::helper::get_tags_for_function "test_slow_operation" "$script")

  assert_same "slow" "$result"
}

function test_get_tags_for_function_returns_multiple_tags() {
  local script="tests/acceptance/fixtures/test_bashunit_with_tags.sh"
  local result
  result=$(bashunit::helper::get_tags_for_function "test_slow_database_query" "$script")

  assert_contains "slow" "$result"
  assert_contains "database" "$result"
}

function test_get_tags_for_function_returns_empty_when_no_tags() {
  local script="tests/acceptance/fixtures/test_bashunit_with_tags.sh"
  local result
  result=$(bashunit::helper::get_tags_for_function "test_no_tags" "$script")

  assert_empty "$result"
}

function test_get_tags_for_function_returns_empty_for_nonexistent_function() {
  local script="tests/acceptance/fixtures/test_bashunit_with_tags.sh"
  local result
  result=$(bashunit::helper::get_tags_for_function "test_nonexistent" "$script")

  assert_empty "$result"
}

function test_function_matches_tags_include_match() {
  local tags="slow,database"
  local include_tags="slow"
  local exclude_tags=""

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 0 "$exit_code"
}

function test_function_matches_tags_include_no_match() {
  local tags="fast"
  local include_tags="slow"
  local exclude_tags=""

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 1 "$exit_code"
}

function test_function_matches_tags_exclude_match() {
  local tags="slow,database"
  local include_tags=""
  local exclude_tags="slow"

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 1 "$exit_code"
}

function test_function_matches_tags_exclude_wins_over_include() {
  local tags="slow,database"
  local include_tags="database"
  local exclude_tags="slow"

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 1 "$exit_code"
}

function test_function_matches_tags_no_tags_with_include_filter() {
  local tags=""
  local include_tags="slow"
  local exclude_tags=""

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 1 "$exit_code"
}

function test_function_matches_tags_no_tags_with_exclude_filter() {
  local tags=""
  local include_tags=""
  local exclude_tags="slow"

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 0 "$exit_code"
}

function test_function_matches_tags_multiple_include_or_logic() {
  local tags="fast"
  local include_tags="slow,fast"
  local exclude_tags=""

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 0 "$exit_code"
}

function test_function_matches_tags_multiple_exclude_or_logic() {
  local tags="fast"
  local include_tags=""
  local exclude_tags="slow,fast"

  local exit_code=0
  bashunit::helper::function_matches_tags "$tags" "$include_tags" "$exclude_tags" || exit_code=$?
  assert_same 1 "$exit_code"
}
