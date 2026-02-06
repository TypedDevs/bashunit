#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

# assert_date_equals

function test_successful_assert_date_equals() {
  assert_empty "$(assert_date_equals "1700000000" "1700000000")"
}

function test_unsuccessful_assert_date_equals() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date equals" "1600000000" "to be equal to" "1700000000")"\
    "$(assert_date_equals "1700000000" "1600000000")"
}

# assert_date_before

function test_successful_assert_date_before() {
  assert_empty "$(assert_date_before "1700000000" "1600000000")"
}

function test_unsuccessful_assert_date_before() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date before" "1800000000" "to be before" "1700000000")"\
    "$(assert_date_before "1700000000" "1800000000")"
}

# assert_date_after

function test_successful_assert_date_after() {
  assert_empty "$(assert_date_after "1600000000" "1700000000")"
}

function test_unsuccessful_assert_date_after() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date after" "1500000000" "to be after" "1600000000")"\
    "$(assert_date_after "1600000000" "1500000000")"
}

# assert_date_within_range

function test_successful_assert_date_within_range() {
  assert_empty "$(assert_date_within_range "1600000000" "1800000000" "1700000000")"
}

function test_successful_assert_date_within_range_at_lower_bound() {
  assert_empty "$(assert_date_within_range "1600000000" "1800000000" "1600000000")"
}

function test_successful_assert_date_within_range_at_upper_bound() {
  assert_empty "$(assert_date_within_range "1600000000" "1800000000" "1800000000")"
}

function test_unsuccessful_assert_date_within_range() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date within range" "1900000000" "to be between" "1600000000 and 1800000000")"\
    "$(assert_date_within_range "1600000000" "1800000000" "1900000000")"
}

# assert_date_within_delta

function test_successful_assert_date_within_delta() {
  assert_empty "$(assert_date_within_delta "1700000000" "1700000005" "10")"
}

function test_successful_assert_date_within_delta_exact() {
  assert_empty "$(assert_date_within_delta "1700000000" "1700000010" "10")"
}

function test_unsuccessful_assert_date_within_delta() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date within delta" "1700000020" "to be within" "5 seconds of 1700000000")"\
    "$(assert_date_within_delta "1700000000" "1700000020" "5")"
}
