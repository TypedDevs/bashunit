#!/bin/bash

# shellcheck disable=SC2034

function test_add_and_get_tests_passed() {
  local tests_passed
  tests_passed=$(
    _TESTS_PASSED=0

    state::add_tests_passed
    state::get_tests_passed
  )

  assert_same "1" "$tests_passed"
}

function test_add_and_get_tests_failed() {
  local tests_failed
  tests_failed=$(
    _TESTS_FAILED=0

    state::add_tests_failed
    state::get_tests_failed
  )

  assert_same "1" "$tests_failed"
}

function test_add_and_get_tests_skipped() {
  local tests_skipped
  tests_skipped=$(
    _TESTS_SKIPPED=0

    state::add_tests_skipped
    state::get_tests_skipped
  )

  assert_same "1" "$tests_skipped"
}

function test_add_and_get_tests_incomplete() {
  local tests_incomplete
  tests_incomplete=$(
    _TESTS_INCOMPLETE=0

    state::add_tests_incomplete
    state::get_tests_incomplete
  )

  assert_same "1" "$tests_incomplete"
}

function test_add_and_get_tests_snapshot() {
  local tests_snapshot
  tests_snapshot=$(
    _TESTS_SNAPSHOT=0

    state::add_tests_snapshot
    state::get_tests_snapshot
  )

  assert_same "1" "$tests_snapshot"
}

function test_add_twice_and_get_tests_snapshot() {
  local tests_snapshot
  tests_snapshot=$(
    _TESTS_SNAPSHOT=0

    state::add_tests_snapshot
    state::add_tests_snapshot
    state::get_tests_snapshot
  )

  assert_same "2" "$tests_snapshot"
}

function test_add_and_get_assertions_passed() {
  local assertions_passed
  assertions_passed=$(
    _ASSERTIONS_PASSED=0

    state::add_assertions_passed
    state::get_assertions_passed
  )

  assert_same "1" "$assertions_passed"
}

function test_add_and_get_assertions_failed() {
  local assertions_failed
  assertions_failed=$(
    _ASSERTIONS_FAILED=0

    state::add_assertions_failed
    state::get_assertions_failed
  )

  assert_same "1" "$assertions_failed"
}

function test_add_and_get_assertions_skipped() {
  local assertions_skipped
  assertions_skipped=$(
    _ASSERTIONS_FAILED=0

    state::add_assertions_skipped
    state::get_assertions_skipped
  )

  assert_same "1" "$assertions_skipped"
}

function test_add_and_get_assertions_incomplete() {
  local assertions_incomplete
  assertions_incomplete=$(
    _ASSERTIONS_INCOMPLETE=0

    state::add_assertions_incomplete
    state::get_assertions_incomplete
  )

  assert_same "1" "$assertions_incomplete"
}

function test_add_and_get_assertions_snapshot() {
  local assertions_snapshot
  assertions_snapshot=$(
    _ASSERTIONS_SNAPSHOT=0

    state::add_assertions_snapshot
    state::get_assertions_snapshot
  )

  assert_same "1" "$assertions_snapshot"
}

function test_add_twice_and_get_assertions_snapshot() {
  local assertions_snapshot
  assertions_snapshot=$(
    _ASSERTIONS_SNAPSHOT=0

    state::add_assertions_snapshot
    state::add_assertions_snapshot
    state::get_assertions_snapshot
  )

  assert_same "2" "$assertions_snapshot"
}

function test_set_and_is_duplicated_test_functions_found() {
  local duplicated_test_functions_found
  duplicated_test_functions_found=$(
    _DUPLICATED_TEST_FUNCTIONS_FOUND=false

    state::set_duplicated_test_functions_found
    state::is_duplicated_test_functions_found
  )

  assert_same "true" "$duplicated_test_functions_found"
}

function test_set_and_get_file_with_duplicated_function_names() {
  local file_with_duplicated_function_names
  file_with_duplicated_function_names=$(
    _FILE_WITH_DUPLICATED_FUNCTION_NAMES=""

    state::set_file_with_duplicated_function_names "test_path/file_name_test.sh"
    state::get_file_with_duplicated_function_names
  )

  assert_same "test_path/file_name_test.sh" "$file_with_duplicated_function_names"
}

function test_set_and_get_duplicated_function_names_one_name() {
  local duplicated_function_names
  duplicated_function_names=$(
    _DUPLICATED_FUNCTION_NAMES=""

    state::set_duplicated_function_names "duplicated_test_name"
    state::get_duplicated_function_names
  )

  assert_same "duplicated_test_name" "$duplicated_function_names"
}

function test_set_and_get_duplicated_function_names_multiply_names() {
  local test_names="duplicated_test_function1
duplicated_test_function2
duplicated_test_function3"

  local duplicated_function_names
  duplicated_function_names=$(
    _DUPLICATED_FUNCTION_NAMES=""

    state::set_duplicated_function_names "$test_names"
    state::get_duplicated_function_names
  )

  assert_same "$test_names" "$duplicated_function_names"
}

function test_set_duplicated_functions_merged() {
  local test_function_name="test_function_name"
  local test_file_name="test_file_name.sh"

  duplicated_test_functions_found=$(
    _DUPLICATED_TEST_FUNCTIONS_FOUND=false

    state::set_duplicated_functions_merged "$test_file_name" "$test_function_name"
    state::is_duplicated_test_functions_found
  )

  assert_same "true" "$duplicated_test_functions_found"

  local duplicated_function_names
  duplicated_function_names=$(
    _DUPLICATED_FUNCTION_NAMES=""

    state::set_duplicated_functions_merged "$test_file_name" "$test_function_name"
    state::get_duplicated_function_names
  )
  assert_same "$test_function_name" "$duplicated_function_names"

  local file_with_duplicated_function_names
  file_with_duplicated_function_names=$(
    _FILE_WITH_DUPLICATED_FUNCTION_NAMES=""

    state::set_duplicated_functions_merged "$test_file_name" "$test_function_name"
    state::get_file_with_duplicated_function_names
  )

  assert_same "$test_file_name" "$file_with_duplicated_function_names"
}

function test_initialize_assertions_count() {
  local export_assertions_count
  export_assertions_count=$(
    _ASSERTIONS_PASSED=10
    _ASSERTIONS_FAILED=5
    _ASSERTIONS_SKIPPED=42
    _ASSERTIONS_INCOMPLETE=12
    _ASSERTIONS_SNAPSHOT=33

    state::initialize_assertions_count
    state::export_assertions_count
  )

  assert_same\
    "##ASSERTIONS_FAILED=0\
##ASSERTIONS_PASSED=0\
##ASSERTIONS_SKIPPED=0\
##ASSERTIONS_INCOMPLETE=0\
##ASSERTIONS_SNAPSHOT=0\
##"\
    "$export_assertions_count"
}

function test_export_assertions_count() {
  local export_assertions_count
  export_assertions_count=$(
    _ASSERTIONS_PASSED=10
    _ASSERTIONS_FAILED=5
    _ASSERTIONS_SKIPPED=42
    _ASSERTIONS_INCOMPLETE=12
    _ASSERTIONS_SNAPSHOT=33

    state::export_assertions_count
  )

  assert_same\
    "##ASSERTIONS_FAILED=5##\
ASSERTIONS_PASSED=10##\
ASSERTIONS_SKIPPED=42##\
ASSERTIONS_INCOMPLETE=12##\
ASSERTIONS_SNAPSHOT=33##"\
    "$export_assertions_count"
}

function test_calculate_total_assertions() {
  local input="##ASSERTIONS_FAILED=1\
  ##ASSERTIONS_PASSED=2\
  ##ASSERTIONS_SKIPPED=3\
  ##ASSERTIONS_INCOMPLETE=4\
  ##ASSERTIONS_SNAPSHOT=5##"

  assert_same 15 "$(state::calculate_total_assertions "$input")"
}
