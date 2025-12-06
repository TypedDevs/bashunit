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
  assert_same\
    "$(console_results::print_failed_test "Assert foo failed" "foo" "but got " "bar")"\
    "$(assert_foo "bar")"
}

function test_assert_positive_number_passed() {
  assert_positive_number "1"
}

function test_assert_positive_number_failed() {
  assert_same\
    "$(console_results::print_failed_test "Assert positive number failed" "positive number" "got" "0")"\
    "$(assert_positive_number "0")"
}
