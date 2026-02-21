#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_assert_exit_code() {
  function fake_function() {
    exit 0
  }

  assert_empty "$(assert_exit_code "0" "$(fake_function)")"
}

function test_unsuccessful_assert_exit_code() {
  function fake_function() {
    exit 1
  }

  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert exit code" "1" "to be" "0")" \
    "$(assert_exit_code "0" "$(fake_function)")"
}

function test_successful_return_assert_exit_code() {
  function fake_function() {
    return 0
  }

  fake_function

  assert_exit_code "0"
}

function test_unsuccessful_return_assert_exit_code() {
  function fake_function() {
    return 1
  }

  assert_exit_code "1" "$(fake_function)"
}

function test_successful_assert_successful_code() {
  function fake_function() {
    return 0
  }

  assert_empty "$(assert_successful_code "$(fake_function)")"
}

function test_unsuccessful_assert_successful_code() {
  function fake_function() {
    return 2
  }

  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert successful code" "2" "to be exactly" "0")" \
    "$(assert_successful_code "$(fake_function)")"
}

function test_successful_assert_unsuccessful_code() {
  function fake_function() {
    return 2
  }

  assert_empty "$(assert_unsuccessful_code "$(fake_function)")"
}

function test_unsuccessful_assert_unsuccessful_code() {
  function fake_function() {
    return 0
  }

  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert unsuccessful code" "0" "to be non-zero" "but was 0")"
  assert_same "$expected" "$(assert_unsuccessful_code "$(fake_function)")"
}

function test_successful_assert_less_than() {
  assert_empty "$(assert_less_than "3" "1")"
}

function test_unsuccessful_assert_less_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert less than" "3" "to be less than" "1")" \
    "$(assert_less_than "1" "3")"
}

function test_successful_assert_less_or_equal_than_with_a_smaller_number() {
  assert_empty "$(assert_less_or_equal_than "3" "1")"
}

function test_successful_assert_less_or_equal_than_with_an_equal_number() {
  assert_empty "$(assert_less_or_equal_than "3" "3")"
}

function test_unsuccessful_assert_less_or_equal_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert less or equal than" "3" "to be less or equal than" "1")" \
    "$(assert_less_or_equal_than "1" "3")"
}

function test_successful_assert_greater_than() {
  assert_empty "$(assert_greater_than "1" "3")"
}

function test_unsuccessful_assert_greater_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert greater than" "1" "to be greater than" "3")" \
    "$(assert_greater_than "3" "1")"
}

function test_successful_assert_greater_or_equal_than_with_a_smaller_number() {
  assert_empty "$(assert_greater_or_equal_than "1" "3")"
}

function test_successful_assert_greater_or_equal_than_with_an_equal_number() {
  assert_empty "$(assert_greater_or_equal_than "3" "3")"
}

function test_unsuccessful_assert_greater_or_equal_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert greater or equal than" "1" "to be greater or equal than" "3")" \
    "$(assert_greater_or_equal_than "3" "1")"
}
