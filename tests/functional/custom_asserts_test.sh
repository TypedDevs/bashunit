#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  # shellcheck disable=SC1091
  source "$(bashunit::current_dir)/custom_asserts.sh"
}

function test_assert_foo_passed() {
  assert_foo "foo"
}

function test_assert_foo_failed() {
  assert_same "$(bashunit::console_results::print_failed_test "Assert foo failed" "foo" "but got " "bar")" \
    "$(assert_foo "bar")"
}

function test_assert_positive_number_passed() {
  assert_positive_number "1"
}

function test_assert_positive_number_failed() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Assert positive number failed" "positive number" "got" "0")" \
    "$(assert_positive_number "0")"
}

function test_assert_that_positive_number_passed() {
  assert_that_positive_number "1"
}

function test_assert_that_positive_number_failed() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert that positive number failed" "positive number" "but got " "0")" \
    "$(assert_that_positive_number "0" || true)"
}

function test_assert_labelled_foo_passed() {
  assert_labelled_foo "foo"
}

function test_assert_labelled_foo_failed() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Assert labelled foo" "foo" "but got " "bar")" \
    "$(assert_labelled_foo "bar")"
}
