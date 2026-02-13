#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_fail() {
  true || bashunit::fail "This cannot fail"
}

function test_unsuccessful_fail() {
  assert_same "$(bashunit::console_results::print_failure_message \
    "Unsuccessful fail" "Failure message")" \
    "$(bashunit::fail "Failure message")"
}

# @data_provider provider_successful_assert_true
function test_successful_assert_true() {
  # shellcheck disable=SC2086
  assert_empty "$(assert_true $1)"
}

function provider_successful_assert_true() {
  bashunit::data_set true
  bashunit::data_set "true"
  bashunit::data_set 0
}

function test_unsuccessful_assert_true() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert true" \
    "true or 0" \
    "but got " "false")" \
    "$(assert_true false)"
}

function test_successful_assert_true_on_function() {
  assert_empty "$(assert_true ls)"
}

function test_unsuccessful_assert_true_on_function() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert true on function" \
    "command or function with zero exit code" \
    "but got " "exit code: 2")" \
    "$(assert_true "eval return 2")"
}

# @data_provider provider_successful_assert_false
function test_successful_assert_false() {
  # shellcheck disable=SC2086
  assert_empty "$(assert_false $1)"
}

function provider_successful_assert_false() {
  bashunit::data_set false
  bashunit::data_set "false"
  bashunit::data_set 1
}

function test_unsuccessful_assert_false() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert false" \
    "false or 1" \
    "but got " "true")" \
    "$(assert_false true)"
}

function test_successful_assert_false_on_function() {
  assert_empty "$(assert_false "eval return 1")"
}

function test_unsuccessful_assert_false_on_function() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert false on function" \
    "command or function with non-zero exit code" \
    "but got " "exit code: 0")" \
    "$(assert_false "eval return 0")"
}

function test_successful_assert_same() {
  assert_empty "$(assert_same "1" "1")"
}

function test_unsuccessful_assert_same() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert same" "1" "but got " "2")" \
    "$(assert_same "1" "2")"
}

function test_successful_assert_empty() {
  assert_empty "$(assert_empty "")"
}

function test_unsuccessful_assert_empty() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert empty" "to be empty" "but got " "1")" \
    "$(assert_empty "1")"
}
