#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_fail() {
  true || bashunit::fail "This cannot fail"
}

function test_unsuccessful_fail() {
  assert_same\
    "$(bashunit::console_results::print_failure_message \
      "Unsuccessful fail" "Failure message")"\
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
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert true" \
      "true or 0" \
      "but got " "false")"\
    "$(assert_true false)"
}

function test_successful_assert_true_on_function() {
  assert_empty "$(assert_true ls)"
}

function test_unsuccessful_assert_true_on_function() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert true on function"\
      "command or function with zero exit code"\
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
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert false" \
      "false or 1" \
      "but got " "true")"\
    "$(assert_false true)"
}

function test_successful_assert_false_on_function() {
  assert_empty "$(assert_false "eval return 1")"
}

function test_unsuccessful_assert_false_on_function() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert false on function"\
      "command or function with non-zero exit code"\
      "but got " "exit code: 0")" \
    "$(assert_false "eval return 0")"
}

function test_successful_assert_same() {
  assert_empty "$(assert_same "1" "1")"
}

function test_unsuccessful_assert_same() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert same" "1" "but got " "2")"\
    "$(assert_same "1" "2")"
}

function test_successful_assert_empty() {
  assert_empty "$(assert_empty "")"
}

function test_unsuccessful_assert_empty() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert empty" "to be empty" "but got " "1")"\
    "$(assert_empty "1")"
}

function test_successful_assert_not_empty() {
  assert_empty "$(assert_not_empty "a_random_string")"
}

function test_unsuccessful_assert_not_empty() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert not empty" "to not be empty" "but got " "")"\
    "$(assert_not_empty "")"
}

function test_successful_assert_not_same() {
  assert_empty "$(assert_not_same "1" "2")"
}

function test_unsuccessful_assert_not_same() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert not same" "1" "but got " "1")"\
    "$(assert_not_same "1" "1")"
}

function test_successful_assert_not_equals() {
  assert_empty "$(assert_not_equals "1" "2")"
}

function test_unsuccessful_assert_not_equals() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert not equals" "1" "but got " "1")"\
    "$(assert_not_equals "1" "1")"
}

function test_unsuccessful_assert_not_equals_with_special_chars() {
  local str1="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} foo"
  local str2="✗ Failed foo"

  assert_equals\
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert not equals with special chars" \
      "$str1" "but got " "$str2")"\
    "$(assert_not_equals "$str1" "$str2")"
}

function test_successful_assert_contains_ignore_case() {
  assert_empty "$(assert_contains_ignore_case "Linux" "GNU/LINUX")"
}

function test_unsuccessful_assert_contains_ignore_case() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert contains ignore case" "GNU/LINUX" "to contain" "Unix")"
  assert_same "$expected" "$(assert_contains_ignore_case "Unix" "GNU/LINUX")"
}

function test_successful_assert_contains() {
  assert_empty "$(assert_contains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assert_contains() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert contains" "GNU/Linux" "to contain" "Unix")"\
    "$(assert_contains "Unix" "GNU/Linux")"
}

function test_successful_assert_not_contains() {
  assert_empty "$(assert_not_contains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assert_not_contains() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert not contains" "GNU/Linux" "to not contain" "Linux")"
  assert_same "$expected" "$(assert_not_contains "Linux" "GNU/Linux")"
}

function test_successful_assert_matches() {
  assert_empty "$(assert_matches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assert_matches() {
  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert matches" "GNU/Linux" "to match" ".*Pinux*")"\
    "$(assert_matches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assert_not_matches() {
  assert_empty "$(assert_not_matches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assert_not_matches() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert not matches" "GNU/Linux" "to not match" ".*Linu*")"
  assert_same "$expected" "$(assert_not_matches ".*Linu*" "GNU/Linux")"
}

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

  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert exit code" "1" "to be" "0")"\
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

  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert successful code" "2" "to be exactly" "0")"\
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

  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert general error" "2" "to be exactly" "1")"\
    "$(assert_general_error "$(fake_function)")"
}

function test_successful_assert_command_not_found() {
  assert_empty "$(assert_command_not_found "$(a_non_existing_function > /dev/null 2>&1)")"
}

function test_unsuccessful_assert_command_not_found() {
  function fake_function() {
    return 0
  }

  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert command not found" "0" "to be exactly" "127")"\
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

  assert_same\
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert exec" "$expected" "but got " "$actual")"\
    "$(assert_exec fake_command --exit 1 --stdout "Expected" --stderr "Expected error")"
}

function test_successful_assert_array_contains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assert_array_contains "123" "${distros[@]}")"
}

function test_unsuccessful_assert_array_contains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_same\
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert array contains"\
      "Ubuntu 123 Linux Mint"\
      "to contain"\
      "non_existing_element")"\
    "$(assert_array_contains "non_existing_element" "${distros[@]}")"
}

function test_successful_assert_array_not_contains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assert_array_not_contains "a_non_existing_element" "${distros[@]}")"
}

function test_unsuccessful_assert_array_not_contains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert array not contains" "Ubuntu 123 Linux Mint" "to not contain" "123")"\
    "$(assert_array_not_contains "123" "${distros[@]}")"
}

function test_successful_assert_string_starts_with() {
  assert_empty "$(assert_string_starts_with "ho" "house")"
}

function test_unsuccessful_assert_string_starts_with() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert string starts with" "pause" "to start with" "hou")"\
    "$(assert_string_starts_with "hou" "pause")"
}

function test_successful_assert_string_not_starts_with() {
  assert_empty "$(assert_string_not_starts_with "hou" "pause")"
}

function test_unsuccessful_assert_string_not_starts_with() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert string not starts with" "house" "to not start with" "ho")"\
    "$(assert_string_not_starts_with "ho" "house")"
}

function test_successful_assert_string_ends_with() {
  assert_empty "$(assert_string_ends_with "bar" "foobar")"
}

function test_unsuccessful_assert_string_ends_with() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert string ends with" "foobar" "to end with" "foo")"\
    "$(assert_string_ends_with "foo" "foobar")"
}


function test_successful_assert_string_not_ends_with() {
  assert_empty "$(assert_string_not_ends_with "foo" "foobar")"
}

function test_unsuccessful_assert_string_not_ends_with() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert string not ends with" "foobar" "to not end with" "bar")"\
    "$(assert_string_not_ends_with "bar" "foobar")"
}

function test_assert_string_start_end_with_special_chars() {
  assert_empty "$(assert_string_starts_with "foo." "foo.bar")"
  assert_empty "$(assert_string_ends_with ".bar" "foo.bar")"
}

function test_assert_string_start_end_with_special_chars_fail() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert string start end with special chars fail" "fooX" "to start with" "foo.")"\
    "$(assert_string_starts_with "foo." "fooX")"

  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Assert string start end with special chars fail" "fooX" "to end with" ".bar")"\
    "$(assert_string_ends_with ".bar" "fooX")"
}

function test_successful_assert_less_than() {
  assert_empty "$(assert_less_than "3" "1")"
}

function test_unsuccessful_assert_less_than() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert less than" "3" "to be less than" "1")"\
    "$(assert_less_than "1" "3")"
}

function test_successful_assert_less_or_equal_than_with_a_smaller_number() {
  assert_empty "$(assert_less_or_equal_than "3" "1")"
}

function test_successful_assert_less_or_equal_than_with_an_equal_number() {
  assert_empty "$(assert_less_or_equal_than "3" "3")"
}

function test_unsuccessful_assert_less_or_equal_than() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert less or equal than" "3" "to be less or equal than" "1")"\
    "$(assert_less_or_equal_than "1" "3")"
}

function test_successful_assert_greater_than() {
  assert_empty "$(assert_greater_than "1" "3")"
}

function test_unsuccessful_assert_greater_than() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert greater than" "1" "to be greater than" "3")"\
    "$(assert_greater_than "3" "1")"
}

function test_successful_assert_greater_or_equal_than_with_a_smaller_number() {
  assert_empty "$(assert_greater_or_equal_than "1" "3")"
}

function test_successful_assert_greater_or_equal_than_with_an_equal_number() {
  assert_empty "$(assert_greater_or_equal_than "3" "3")"
}

function test_unsuccessful_assert_greater_or_equal_than() {
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert greater or equal than" "1" "to be greater or equal than" "3")"\
    "$(assert_greater_or_equal_than "3" "1")"
}

function test_successful_assert_equals() {
  assert_equals\
    "✗ Failed foo"\
    "${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} foo"
}

function test_successful_assert_equals_with_special_chars() {
  local string="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} foo"

  assert_equals "$string" "$string"
}

function test_unsuccessful_assert_equals() {
  local str1="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} str1"
  local str2="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} str2"

  assert_same\
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert equals"\
      "✗ Failed str1"\
      "but got "\
      "✗ Failed str2")"\
    "$(assert_equals "$str1" "$str2")"
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
  assert_same\
    "$(bashunit::console_results::print_failed_test\
      "Unsuccessful assert line count" "one_line_string" "to contain number of lines equal to" "10" "but found" "1")"\
    "$(assert_line_count 10 "one_line_string")"
}

function test_assert_line_count_does_not_modify_existing_variable() {
  local additional_new_lines="original"
  assert_empty "$(assert_line_count 1 "one")"
  assert_same "original" "$additional_new_lines"
}
