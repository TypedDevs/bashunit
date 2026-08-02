#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_assert_date_equals() {
  assert_empty "$(assert_date_equals "1700000000" "1700000000")"
}

function test_unsuccessful_assert_date_equals() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date equals" "1600000000" "to be equal to" "1700000000")"\
    "$(assert_date_equals "1700000000" "1600000000")"
}

function test_successful_assert_date_before() {
  assert_empty "$(assert_date_before "1700000000" "1600000000")"
}

function test_unsuccessful_assert_date_before() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date before" "1800000000" "to be before" "1700000000")"\
    "$(assert_date_before "1700000000" "1800000000")"
}

function test_unsuccessful_assert_date_before_when_equal() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date before when equal" "1700000000" "to be before" "1700000000")"\
    "$(assert_date_before "1700000000" "1700000000")"
}

function test_successful_assert_date_after() {
  assert_empty "$(assert_date_after "1600000000" "1700000000")"
}

function test_unsuccessful_assert_date_after() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date after" "1500000000" "to be after" "1600000000")"\
    "$(assert_date_after "1600000000" "1500000000")"
}

function test_unsuccessful_assert_date_after_when_equal() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date after when equal" "1600000000" "to be after" "1600000000")"\
    "$(assert_date_after "1600000000" "1600000000")"
}

function test_successful_assert_date_within_range() {
  assert_empty "$(assert_date_within_range "1600000000" "1800000000" "1700000000")"
}

function test_successful_assert_date_within_range_at_lower_bound() {
  assert_empty "$(assert_date_within_range "1600000000" "1800000000" "1600000000")"
}

function test_successful_assert_date_within_range_at_upper_bound() {
  assert_empty "$(assert_date_within_range "1600000000" "1800000000" "1800000000")"
}

function test_unsuccessful_assert_date_within_range_above() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date within range above" "1900000000"\
      "to be between" "1600000000 and 1800000000")"\
    "$(assert_date_within_range "1600000000" "1800000000" "1900000000")"
}

function test_unsuccessful_assert_date_within_range_below() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date within range below" "1500000000"\
      "to be between" "1600000000 and 1800000000")"\
    "$(assert_date_within_range "1600000000" "1800000000" "1500000000")"
}

function test_successful_assert_date_within_delta() {
  assert_empty "$(assert_date_within_delta "1700000000" "1700000005" "10")"
}

function test_successful_assert_date_within_delta_exact() {
  assert_empty "$(assert_date_within_delta "1700000000" "1700000010" "10")"
}

function test_successful_assert_date_within_delta_negative_direction() {
  assert_empty "$(assert_date_within_delta "1700000010" "1700000000" "10")"
}

function test_unsuccessful_assert_date_within_delta() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert date within delta" "1700000020"\
      "to be within" "5 seconds of 1700000000")"\
    "$(assert_date_within_delta "1700000000" "1700000020" "5")"
}

# ISO 8601 auto-detection tests

function test_successful_assert_date_equals_with_iso_dates() {
  assert_empty "$(assert_date_equals "2023-06-15" "2023-06-15")"
}

function test_successful_assert_date_before_with_iso_dates() {
  assert_empty "$(assert_date_before "2024-01-01" "2023-01-01")"
}

function test_successful_assert_date_after_with_iso_dates() {
  assert_empty "$(assert_date_after "2023-01-01" "2024-01-01")"
}

function test_successful_assert_date_within_range_with_iso_dates() {
  assert_empty\
    "$(assert_date_within_range "2023-01-01" "2023-12-31" "2023-06-15")"
}

function test_successful_assert_date_equals_with_mixed_formats() {
  local epoch
  epoch=$(date -d "2023-06-15" +%s 2>/dev/null) \
    || epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "2023-06-15 00:00:00" +%s 2>/dev/null)

  assert_empty "$(assert_date_equals "$epoch" "2023-06-15")"
}

function test_successful_assert_date_within_delta_with_iso_datetime() {
  assert_empty\
    "$(assert_date_within_delta "2023-11-14T12:00:00" "2023-11-14T12:00:05" "10")"
}

# Space-separated datetime format tests

function test_successful_assert_date_equals_with_space_separated_datetime() {
  assert_empty "$(assert_date_equals "2023-11-14 12:00:00" "2023-11-14 12:00:00")"
}

function test_successful_assert_date_equals_iso_vs_space_separated() {
  assert_empty "$(assert_date_equals "2023-11-14T12:00:00" "2023-11-14 12:00:00")"
}

function test_successful_assert_date_before_with_space_separated_datetime() {
  assert_empty "$(assert_date_before "2023-11-14 13:00:00" "2023-11-14 12:00:00")"
}

function test_successful_assert_date_equals_epoch_vs_space_separated() {
  local epoch
  epoch=$(date -d "2023-11-14 12:00:00" +%s 2>/dev/null) \
    || epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "2023-11-14 12:00:00" +%s 2>/dev/null)

  assert_empty "$(assert_date_equals "$epoch" "2023-11-14 12:00:00")"
}

# UTC Z suffix test

function test_successful_assert_date_equals_with_utc_z_suffix() {
  assert_empty "$(assert_date_equals "2023-11-14T14:00:00+0200" "2023-11-14T12:00:00Z")"
}

# Timezone offset tests

function test_successful_assert_date_equals_with_tz_offset() {
  assert_empty "$(assert_date_equals "2023-11-14T12:00:00+0100" "2023-11-14T12:00:00+0100")"
}

# Unparseable input tests
#
# bashunit::date::to_epoch signals an unparseable date with `return 1`, echoing
# the raw input back. Every assert_date_* used to capture only the echoed value
# and ignore that return code, so the raw string flowed on into an unguarded
# integer comparison (assert_date_equals/_before/_after/_within_range) or
# `$(( ))` arithmetic (assert_date_within_delta). Depending on the exact
# garbage, that either crashed with a raw "integer expression expected" shell
# error (a hyphenated string) or silently coerced to 0 and produced a wrong
# answer with no error at all (a plain word, or two equal garbage/empty
# strings comparing "equal" to each other). Each assertion must instead fail
# cleanly, the same way any other invalid input does.

function test_assert_date_equals_fails_cleanly_on_unparseable_expected() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date equals fails cleanly on unparseable expected" "not-a-date" "to be" "a valid date")"\
    "$(assert_date_equals "not-a-date" "1700000000")"
}

function test_assert_date_equals_fails_cleanly_on_unparseable_actual() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date equals fails cleanly on unparseable actual" "banana" "to be" "a valid date")"\
    "$(assert_date_equals "1700000000" "banana")"
}

function test_assert_date_before_fails_cleanly_on_unparseable_arg() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date before fails cleanly on unparseable arg" "banana" "to be" "a valid date")"\
    "$(assert_date_before "banana" "1700000000")"
}

function test_assert_date_after_fails_cleanly_on_unparseable_arg() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date after fails cleanly on unparseable arg" "banana" "to be" "a valid date")"\
    "$(assert_date_after "banana" "1700000000")"
}

function test_assert_date_within_range_fails_cleanly_on_unparseable_actual() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date within range fails cleanly on unparseable actual" "banana" "to be" "a valid date")"\
    "$(assert_date_within_range "1600000000" "1800000000" "banana")"
}

function test_assert_date_within_delta_does_not_silently_pass_two_equal_garbage_strings() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date within delta does not silently pass two equal garbage strings" "banana" "to be" "a valid date")"\
    "$(assert_date_within_delta "banana" "banana" "5")"
}

function test_assert_date_within_delta_does_not_silently_pass_two_empty_strings() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert date within delta does not silently pass two empty strings" "" "to be" "a valid date")"\
    "$(assert_date_within_delta "" "" "5")"
}
