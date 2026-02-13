#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_assert_not_empty() {
  assert_empty "$(assert_not_empty "a_random_string")"
}

function test_unsuccessful_assert_not_empty() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert not empty" "to not be empty" "but got " "")" \
    "$(assert_not_empty "")"
}

function test_successful_assert_not_same() {
  assert_empty "$(assert_not_same "1" "2")"
}

function test_unsuccessful_assert_not_same() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert not same" "1" "but got " "1")" \
    "$(assert_not_same "1" "1")"
}

function test_successful_assert_general_error() {
  function fake_function() {
    return 1
  }

  assert_empty "$(assert_general_error "$(fake_function)")"
}

function test_unsuccessful_assert_general_error() {
  function fake_function() {
    return 2
  }

  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert general error" "2" "to be exactly" "1")" \
    "$(assert_general_error "$(fake_function)")"
}

function test_successful_assert_command_not_found() {
  assert_empty "$(assert_command_not_found "$(a_non_existing_function >/dev/null 2>&1)")"
}

function test_unsuccessful_assert_command_not_found() {
  function fake_function() {
    return 0
  }

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert command not found" "0" "to be exactly" "127")" \
    "$(assert_command_not_found "$(fake_function)")"
}

function test_successful_assert_exec() {
  # shellcheck disable=SC2317
  function fake_command() {
    echo "Expected output"
    echo "Expected error" >&2
    return 1
  }

  assert_empty "$(assert_exec fake_command --exit 1 --stdout "Expected output" --stderr "Expected error")"
}

function test_unsuccessful_assert_exec() {
  # shellcheck disable=SC2317
  function fake_command() {
    echo "out"
    echo "err" >&2
    return 0
  }

  local expected="exit: 1"$'\n'"stdout: Expected"$'\n'"stderr: Expected error"
  local actual="exit: 0"$'\n'"stdout: out"$'\n'"stderr: err"

  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert exec" "$expected" "but got " "$actual")" \
    "$(assert_exec fake_command --exit 1 --stdout "Expected" --stderr "Expected error")"
}

function test_successful_assert_array_contains() {
  local distros
  distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assert_array_contains "123" "${distros[@]}")"
}

function test_unsuccessful_assert_array_contains() {
  local distros
  distros=(Ubuntu 123 Linux\ Mint)

  assert_same "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert array contains" \
    "Ubuntu 123 Linux Mint" \
    "to contain" \
    "non_existing_element")" \
    "$(assert_array_contains "non_existing_element" "${distros[@]}")"
}

function test_successful_assert_array_not_contains() {
  local distros
  distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assert_array_not_contains "a_non_existing_element" "${distros[@]}")"
}

function test_unsuccessful_assert_array_not_contains() {
  local distros
  distros=(Ubuntu 123 Linux\ Mint)

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert array not contains" "Ubuntu 123 Linux Mint" "to not contain" "123")" \
    "$(assert_array_not_contains "123" "${distros[@]}")"
}

function test_successful_assert_line_count_empty_str() {
  assert_empty "$(assert_line_count 0 "")"
}

function test_successful_assert_line_count_one_line() {
  assert_empty "$(assert_line_count 1 "one line")"
}

function test_successful_assert_count_multiline() {
  local multiline_string="this is line one
  this is line two
  this is line three"

  assert_empty "$(assert_line_count 3 "$multiline_string")"
}

function test_successful_assert_line_count_multiline_string_in_one_line() {
  assert_empty "$(assert_line_count 4 "one\ntwo\nthree\nfour")"
}

function test_successful_assert_line_count_multiline_with_new_lines() {
  local multiline_str="this \n is \n a multiline \n in one
  \n
  this is line 7
  this is \n line nine
  "

  assert_empty "$(assert_line_count 10 "$multiline_str")"
}

function test_unsuccessful_assert_line_count() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert line count" "one_line_string" "to contain number of lines equal to" "10" "but found" "1")" \
    "$(assert_line_count 10 "one_line_string")"
}

function test_assert_line_count_does_not_modify_existing_variable() {
  local additional_new_lines="original"
  assert_empty "$(assert_line_count 1 "one")"
  assert_same "original" "$additional_new_lines"
}
