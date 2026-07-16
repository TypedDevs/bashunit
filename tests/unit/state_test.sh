#!/usr/bin/env bash

# shellcheck disable=SC2034

function test_add_and_get_tests_passed() {
  local tests_passed
  tests_passed=$(
    _BASHUNIT_TESTS_PASSED=0

    bashunit::state::add_tests_passed
    bashunit::state::get_tests_passed
  )

  assert_same "1" "$tests_passed"
}

function test_add_and_get_tests_failed() {
  local tests_failed
  tests_failed=$(
    _BASHUNIT_TESTS_FAILED=0

    bashunit::state::add_tests_failed
    bashunit::state::get_tests_failed
  )

  assert_same "1" "$tests_failed"
}

function test_add_and_get_tests_skipped() {
  local tests_skipped
  tests_skipped=$(
    _BASHUNIT_TESTS_SKIPPED=0

    bashunit::state::add_tests_skipped
    bashunit::state::get_tests_skipped
  )

  assert_same "1" "$tests_skipped"
}

function test_add_and_get_tests_incomplete() {
  local tests_incomplete
  tests_incomplete=$(
    _BASHUNIT_TESTS_INCOMPLETE=0

    bashunit::state::add_tests_incomplete
    bashunit::state::get_tests_incomplete
  )

  assert_same "1" "$tests_incomplete"
}

function test_add_and_get_tests_snapshot() {
  local tests_snapshot
  tests_snapshot=$(
    _BASHUNIT_TESTS_SNAPSHOT=0

    bashunit::state::add_tests_snapshot
    bashunit::state::get_tests_snapshot
  )

  assert_same "1" "$tests_snapshot"
}

function test_add_twice_and_get_tests_snapshot() {
  local tests_snapshot
  tests_snapshot=$(
    _BASHUNIT_TESTS_SNAPSHOT=0

    bashunit::state::add_tests_snapshot
    bashunit::state::add_tests_snapshot
    bashunit::state::get_tests_snapshot
  )

  assert_same "2" "$tests_snapshot"
}

function test_add_and_get_assertions_passed() {
  local assertions_passed
  assertions_passed=$(
    _BASHUNIT_ASSERTIONS_PASSED=0

    bashunit::state::add_assertions_passed
    bashunit::state::get_assertions_passed
  )

  assert_same "1" "$assertions_passed"
}

function test_add_and_get_assertions_failed() {
  local assertions_failed
  assertions_failed=$(
    _BASHUNIT_ASSERTIONS_FAILED=0

    bashunit::state::add_assertions_failed
    bashunit::state::get_assertions_failed
  )

  assert_same "1" "$assertions_failed"
}

function test_add_and_get_assertions_skipped() {
  local assertions_skipped
  assertions_skipped=$(
    _BASHUNIT_ASSERTIONS_FAILED=0

    bashunit::state::add_assertions_skipped
    bashunit::state::get_assertions_skipped
  )

  assert_same "1" "$assertions_skipped"
}

function test_add_and_get_assertions_incomplete() {
  local assertions_incomplete
  assertions_incomplete=$(
    _BASHUNIT_ASSERTIONS_INCOMPLETE=0

    bashunit::state::add_assertions_incomplete
    bashunit::state::get_assertions_incomplete
  )

  assert_same "1" "$assertions_incomplete"
}

function test_add_and_get_assertions_snapshot() {
  local assertions_snapshot
  assertions_snapshot=$(
    _BASHUNIT_ASSERTIONS_SNAPSHOT=0

    bashunit::state::add_assertions_snapshot
    bashunit::state::get_assertions_snapshot
  )

  assert_same "1" "$assertions_snapshot"
}

function test_add_twice_and_get_assertions_snapshot() {
  local assertions_snapshot
  assertions_snapshot=$(
    _BASHUNIT_ASSERTIONS_SNAPSHOT=0

    bashunit::state::add_assertions_snapshot
    bashunit::state::add_assertions_snapshot
    bashunit::state::get_assertions_snapshot
  )

  assert_same "2" "$assertions_snapshot"
}

function test_set_and_is_duplicated_test_functions_found() {
  local duplicated_test_functions_found
  duplicated_test_functions_found=$(
    _BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=false

    bashunit::state::set_duplicated_test_functions_found
    bashunit::state::is_duplicated_test_functions_found
  )

  assert_true "$duplicated_test_functions_found"
}

function test_set_and_get_file_with_duplicated_function_names() {
  local file_with_duplicated_function_names
  file_with_duplicated_function_names=$(
    _BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""

    bashunit::state::set_file_with_duplicated_function_names "test_path/file_name_test.sh"
    bashunit::state::get_file_with_duplicated_function_names
  )

  assert_same "test_path/file_name_test.sh" "$file_with_duplicated_function_names"
}

function test_set_and_get_duplicated_function_names_one_name() {
  local duplicated_function_names
  duplicated_function_names=$(
    _BASHUNIT_DUPLICATED_FUNCTION_NAMES=""

    bashunit::state::set_duplicated_function_names "duplicated_test_name"
    bashunit::state::get_duplicated_function_names
  )

  assert_same "duplicated_test_name" "$duplicated_function_names"
}

function test_set_and_get_duplicated_function_names_multiply_names() {
  local test_names="duplicated_test_function1
duplicated_test_function2
duplicated_test_function3"

  local duplicated_function_names
  duplicated_function_names=$(
    _BASHUNIT_DUPLICATED_FUNCTION_NAMES=""

    bashunit::state::set_duplicated_function_names "$test_names"
    bashunit::state::get_duplicated_function_names
  )

  assert_same "$test_names" "$duplicated_function_names"
}

function test_set_duplicated_functions_merged() {
  local test_function_name="test_function_name"
  local test_file_name="test_file_name.sh"

  duplicated_test_functions_found=$(
    _BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=false

    bashunit::state::set_duplicated_functions_merged "$test_file_name" "$test_function_name"
    bashunit::state::is_duplicated_test_functions_found
  )

  assert_true "$duplicated_test_functions_found"

  local duplicated_function_names
  duplicated_function_names=$(
    _BASHUNIT_DUPLICATED_FUNCTION_NAMES=""

    bashunit::state::set_duplicated_functions_merged "$test_file_name" "$test_function_name"
    bashunit::state::get_duplicated_function_names
  )
  assert_same "$test_function_name" "$duplicated_function_names"

  local file_with_duplicated_function_names
  file_with_duplicated_function_names=$(
    _BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""

    bashunit::state::set_duplicated_functions_merged "$test_file_name" "$test_function_name"
    bashunit::state::get_file_with_duplicated_function_names
  )

  assert_same "$test_file_name" "$file_with_duplicated_function_names"
}

function test_initialize_assertions_count() {
  bashunit::mock tr echo "abc123"

  local export_assertions_count
  export_assertions_count=$(
    _BASHUNIT_ASSERTIONS_PASSED=10
    _BASHUNIT_ASSERTIONS_FAILED=5
    _BASHUNIT_ASSERTIONS_SKIPPED=42
    _BASHUNIT_ASSERTIONS_INCOMPLETE=12
    _BASHUNIT_ASSERTIONS_SNAPSHOT=33

    bashunit::state::initialize_assertions_count
    bashunit::state::export_subshell_context
  )

  assert_same "##ASSERTIONS_FAILED=0\
##ASSERTIONS_PASSED=0\
##ASSERTIONS_SKIPPED=0\
##ASSERTIONS_INCOMPLETE=0\
##ASSERTIONS_SNAPSHOT=0\
##TEST_EXIT_CODE=0\
##TEST_HOOK_FAILURE=\
##TEST_HOOK_MESSAGE=\
##TEST_TITLE=\
##TEST_OUTPUT=\
##" \
    "$export_assertions_count"
}

function test_export_assertions_count() {
  bashunit::mock tr echo "abc123"

  local export_assertions_count
  export_assertions_count=$(
    _BASHUNIT_ASSERTIONS_PASSED=10
    _BASHUNIT_ASSERTIONS_FAILED=5
    _BASHUNIT_ASSERTIONS_SKIPPED=42
    _BASHUNIT_ASSERTIONS_INCOMPLETE=12
    _BASHUNIT_ASSERTIONS_SNAPSHOT=33
    _BASHUNIT_ASSERTIONS_SNAPSHOT=33
    _BASHUNIT_TEST_EXIT_CODE=1
    _BASHUNIT_TEST_OUTPUT="something"

    bashunit::state::export_subshell_context
  )

  assert_same "##ASSERTIONS_FAILED=5\
##ASSERTIONS_PASSED=10\
##ASSERTIONS_SKIPPED=42\
##ASSERTIONS_INCOMPLETE=12\
##ASSERTIONS_SNAPSHOT=33\
##TEST_EXIT_CODE=1\
##TEST_HOOK_FAILURE=\
##TEST_HOOK_MESSAGE=\
##TEST_TITLE=\
##TEST_OUTPUT=$(echo -n "something" | base64)##" \
    "$export_assertions_count"
}

function test_encode_field_returns_empty_for_empty_value() {
  bashunit::state::encode_field ""
  assert_same "" "$_BASHUNIT_STATE_ENCODED_OUT"
}

function test_encode_field_round_trips_a_plain_value() {
  bashunit::state::encode_field "hello world"
  assert_same "hello world" "$(bashunit::helper::decode_base64 "$_BASHUNIT_STATE_ENCODED_OUT")"
}

function test_encode_field_round_trips_a_multiline_value() {
  local value
  value="$(printf 'line one\nline two')"
  bashunit::state::encode_field "$value"
  assert_same "$value" "$(bashunit::helper::decode_base64 "$_BASHUNIT_STATE_ENCODED_OUT")"
}

function test_encode_field_round_trips_a_value_with_ansi_codes() {
  local value
  value="$(printf '\033[31mred\033[0m')"
  bashunit::state::encode_field "$value"
  assert_same "$value" "$(bashunit::helper::decode_base64 "$_BASHUNIT_STATE_ENCODED_OUT")"
}

function test_decode_base64_returns_empty_for_empty_value() {
  assert_same "" "$(bashunit::helper::decode_base64 "")"
}

function test_calculate_total_assertions() {
  local input="##ASSERTIONS_FAILED=1\
  ##ASSERTIONS_PASSED=2\
  ##ASSERTIONS_SKIPPED=3\
  ##ASSERTIONS_INCOMPLETE=4\
  ##ASSERTIONS_SNAPSHOT=5\
  ##TEST_EXIT_CODE=0\
  ##TEST_OUTPUT=3zhbEncodedBase64##"

  assert_same 15 "$(bashunit::state::calculate_total_assertions "$input")"
}

# --- print_tap_line -----------------------------------------------------------
# Each capture runs in $(...) so mutating _BASHUNIT_TOTAL_TESTS_COUNT never
# leaks into the suite's own counters.

function test_tap_line_successful_strips_colors_and_duration() {
  local line
  line="$(printf '\033[32m✓ Passed\033[0m: Adds numbers 12ms')"

  local out
  out=$(
    _BASHUNIT_TOTAL_TESTS_COUNT=7
    bashunit::state::print_tap_line "successful" "$line"
  )

  assert_same "ok 7 - Adds numbers" "$out"
}

function test_tap_line_failure_renders_yaml_block_without_the_header() {
  local line
  line=$'\033[31m✗ Failed\033[0m: Broken thing\n    Expected \'a\'\n    but got \'b\''

  local out
  out=$(
    _BASHUNIT_TOTAL_TESTS_COUNT=3
    bashunit::state::print_tap_line "failed" "$line"
  )

  local expected
  expected=$'not ok 3 - Broken thing\n  ---\n  Expected \'a\'\n  but got \'b\'\n  ...'
  assert_same "$expected" "$out"
}

function test_tap_line_skipped_with_reason() {
  local out
  out=$(
    _BASHUNIT_TOTAL_TESTS_COUNT=2
    bashunit::state::print_tap_line "skipped" "↷ Skipped: Needs jq   jq not installed"
  )

  assert_same "ok 2 - Needs jq # SKIP jq not installed" "$out"
}

function test_tap_line_skipped_without_reason() {
  local out
  out=$(
    _BASHUNIT_TOTAL_TESTS_COUNT=2
    bashunit::state::print_tap_line "skipped" "↷ Skipped: No reason"
  )

  assert_same "ok 2 - No reason # SKIP" "$out"
}

function test_tap_line_incomplete_and_snapshot_and_risky_directives() {
  local out
  out=$(
    _BASHUNIT_TOTAL_TESTS_COUNT=5
    bashunit::state::print_tap_line "incomplete" "✒ Incomplete: Pending"
    bashunit::state::print_tap_line "snapshot" "✎ Snapshot: Rendered"
    bashunit::state::print_tap_line "risky" "△ Risky: No asserts"
  )

  local expected
  expected=$'ok 5 - Pending # TODO incomplete\nok 5 - Rendered # snapshot\nok 5 - No asserts # RISKY no assertions'
  assert_same "$expected" "$out"
}

function test_tap_line_unknown_type_is_not_ok() {
  local out
  out=$(
    _BASHUNIT_TOTAL_TESTS_COUNT=9
    bashunit::state::print_tap_line "mystery" "?: Something odd"
  )

  assert_same "not ok 9 - Something odd" "$out"
}
