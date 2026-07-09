#!/usr/bin/env bash

function test_successful_assert_within_delta_when_close_enough() {
  assert_empty "$(assert_within_delta "3.14" "3.14159" "0.01")"
}

function test_successful_assert_within_delta_with_integers() {
  assert_empty "$(assert_within_delta "105" "100" "10")"
}

function test_successful_assert_within_delta_on_exact_boundary() {
  assert_empty "$(assert_within_delta "100" "105" "5")"
}

function test_successful_assert_within_delta_with_negative_values() {
  assert_empty "$(assert_within_delta "-1.0" "-1.2" "0.5")"
}

function test_unsuccessful_assert_within_delta_when_out_of_range() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert within delta when out of range" \
      "100" "to be within delta 1 of" "105" "diff" "5")" \
    "$(assert_within_delta "105" "100" "1")"
}

function test_unsuccessful_assert_within_delta_with_non_numeric_argument() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert within delta with non numeric argument" \
      "all arguments to be numeric" "got" "'abc' '100' '1'")" \
    "$(assert_within_delta "abc" "100" "1")"
}

function test_unsuccessful_assert_within_delta_with_negative_delta() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert within delta with negative delta" \
      "delta to be non-negative" "got" "-1")" \
    "$(assert_within_delta "100" "100" "-1")"
}
