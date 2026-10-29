#!/usr/bin/env bash
set -euo pipefail

# --exclude-filter is the name-based counterpart of --exclude-tag (#1009).
# Selection is asserted through --list: same pipeline, exact comparison.

FIXTURE=./tests/acceptance/fixtures/exclude_filter_fixture.sh

function embedded_prefix_filter_fixture() {
  local fixture
  fixture="$(bashunit::temp_file embedded_filter).sh"
  printf 'function %s() { assert_true true; }\n' test_latest_version test_other >"$fixture"
  printf '%s' "$fixture"
}

function provide_embedded_prefix_filter_values() {
  bashunit::data_set latest_version
  bashunit::data_set test_latest_version
  bashunit::data_set version
}

# @data_provider provide_embedded_prefix_filter_values
function test_include_and_inline_filters_preserve_an_embedded_test_prefix() {
  local fixture output
  fixture="$(embedded_prefix_filter_fixture)"
  output=$(./bashunit --skip-env-file --list --filter "$1" "$fixture")
  assert_same "$fixture::test_latest_version" "$output"

  output=$(./bashunit --skip-env-file --list "$fixture::$1")
  assert_same "$fixture::test_latest_version" "$output"
}

# @data_provider provide_embedded_prefix_filter_values
function test_exclusion_filters_preserve_an_embedded_test_prefix() {
  local fixture output
  fixture="$(embedded_prefix_filter_fixture)"
  output=$(./bashunit --skip-env-file --list --exclude-filter "$1" "$fixture")
  assert_same "$fixture::test_other" "$output"

  output=$(BASHUNIT_EXCLUDE_FILTER="$1,missing" ./bashunit --skip-env-file --list "$fixture")
  assert_same "$fixture::test_other" "$output"
}

function test_exclude_filter_skips_matching_tests() {
  local output
  output=$(./bashunit --list --exclude-filter admin "$FIXTURE" 2>/dev/null)

  assert_same "\
$FIXTURE::test_user_list
$FIXTURE::test_report_export" "$output"
}

function test_exclude_filter_combines_with_the_include_filter() {
  local output
  output=$(./bashunit --list --filter user --exclude-filter admin "$FIXTURE" 2>/dev/null)

  assert_same "$FIXTURE::test_user_list" "$output"
}

function test_repeated_exclude_filters_are_or_ed() {
  local output
  output=$(./bashunit --list --exclude-filter admin --exclude-filter report "$FIXTURE" 2>/dev/null)

  assert_same "$FIXTURE::test_user_list" "$output"
}

function test_a_comma_in_one_exclude_filter_stays_literal() {
  local fixture
  fixture="$(bashunit::temp_file comma_filter).sh"
  cat >"$fixture" <<'TEST'
function test_a() { assert_same 1 1; }
function test_a,{b}() { assert_same 1 1; }
TEST

  local output
  output=$(./bashunit --list --filter test_a \
    --exclude-filter 'test_a,{b}' "$fixture" 2>/dev/null)

  assert_same "$fixture::test_a" "$output"
}

function test_exclude_filter_wins_when_a_name_matches_both() {
  local output
  output=$(./bashunit --list --filter admin --exclude-filter admin "$FIXTURE" 2>/dev/null)

  assert_empty "$output"
}

# Not selected at all, so nothing is reported as skipped — same as --exclude-tag.
function test_excluded_tests_are_not_reported_as_skipped() {
  local output
  output=$(./bashunit --no-parallel --exclude-filter admin "$FIXTURE" 2>&1)

  assert_not_contains "skipped" "$output"
}

function test_excluded_tests_are_not_counted_in_the_header() {
  local output
  output=$(./bashunit --no-parallel --exclude-filter admin "$FIXTURE" 2>&1)

  # The header count and the runner must agree, or the summary reads as if
  # tests vanished mid-run.
  assert_contains "Tests: 2" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_exclude_filter_works_with_explicit_function_targeting() {
  local output
  output=$(./bashunit --list --exclude-filter admin "$FIXTURE::test_user_admin" 2>/dev/null)

  assert_empty "$output"
}

function test_without_the_flag_every_test_is_selected() {
  local output
  output=$(./bashunit --list "$FIXTURE" 2>/dev/null)

  assert_same "\
$FIXTURE::test_user_list
$FIXTURE::test_user_admin
$FIXTURE::test_report_export" "$output"
}
