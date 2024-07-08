#!/bin/bash

function set_up() {
  _ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
  source "$_ROOT_DIR/custom_asserts.sh"
}

function test_assert_foo_passed() {
  assert_foo "foo"
}

function test_assert_foo_failed() {
  assert_equals\
    "$(console_results::print_failed_test "Assert foo" "foo" "but got" "bar")"\
    "$(assert_foo "bar")"
}

function test_assert_positive_number_passed() {
  assert_positive_number "1"
}

function test_assert_positive_number_failed() {
  assert_equals\
    "$(console_results::print_failed_test "Assert positive number" "positive number" "got" "0")"\
    "$(assert_positive_number "0")"
}
