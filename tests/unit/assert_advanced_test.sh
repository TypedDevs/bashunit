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
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert not same" "1" "to not be" "1")" \
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

function test_successful_assert_arrays_equal() {
  local expected_values
  expected_values=(Ubuntu 123 Linux\ Mint)
  local actual_values
  actual_values=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assert_arrays_equal "${expected_values[@]}" -- "${actual_values[@]}")"
}

function test_unsuccessful_assert_arrays_equal_with_different_lengths() {
  local expected_values
  expected_values=(Ubuntu 123 Linux\ Mint)
  local actual_values
  actual_values=(Ubuntu 123)

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert arrays equal with different lengths" \
    "Ubuntu 123 Linux Mint" "but got " "Ubuntu 123" "Expected length" "3, actual length 2")" \
    "$(assert_arrays_equal "${expected_values[@]}" -- "${actual_values[@]}")"
}

function test_unsuccessful_assert_arrays_equal_with_different_elements() {
  local expected_values
  expected_values=(Ubuntu 123 Linux\ Mint)
  local actual_values
  actual_values=(Ubuntu 321 Linux\ Mint)

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert arrays equal with different elements" \
    "Ubuntu 123 Linux Mint" "but got " "Ubuntu 321 Linux Mint" "Different index" "1")" \
    "$(assert_arrays_equal "${expected_values[@]}" -- "${actual_values[@]}")"
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

function test_successful_assert_exec_with_stdin() {
  # shellcheck disable=SC2317
  function prompt_command() {
    local name lang
    read -r name
    read -r lang
    echo "Your name is $name and you prefer $lang."
  }

  assert_empty "$(assert_exec prompt_command \
    --stdin "Chemaclass"$'\n'"Phel-Lang"$'\n' \
    --stdout "Your name is Chemaclass and you prefer Phel-Lang." \
    --exit 0)"
}

function test_successful_assert_exec_stdout_contains() {
  # shellcheck disable=SC2317
  function greet_command() {
    echo "Hello, World! Welcome to bashunit."
  }

  assert_empty "$(assert_exec greet_command --stdout-contains "bashunit")"
}

function test_unsuccessful_assert_exec_stdout_contains() {
  # shellcheck disable=SC2317
  function greet_command() {
    echo "Hello, World!"
  }

  local expected="exit: 0"$'\n'"stdout contains: bashunit"
  local actual="exit: 0"$'\n'"stdout: Hello, World!"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert exec stdout contains" "$expected" "but got " "$actual")" \
    "$(assert_exec greet_command --stdout-contains "bashunit")"
}

function test_successful_assert_exec_stdout_not_contains() {
  # shellcheck disable=SC2317
  function greet_command() {
    echo "Hello, World!"
  }

  assert_empty "$(assert_exec greet_command --stdout-not-contains "Delphi")"
}

function test_unsuccessful_assert_exec_stdout_not_contains() {
  # shellcheck disable=SC2317
  function greet_command() {
    echo "Hello, Delphi lovers!"
  }

  local expected="exit: 0"$'\n'"stdout not contains: Delphi"
  local actual="exit: 0"$'\n'"stdout: Hello, Delphi lovers!"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert exec stdout not contains" "$expected" "but got " "$actual")" \
    "$(assert_exec greet_command --stdout-not-contains "Delphi")"
}

function test_successful_assert_exec_stderr_contains() {
  # shellcheck disable=SC2317
  function warn_command() {
    echo "warning: low disk" >&2
  }

  assert_empty "$(assert_exec warn_command --stderr-contains "low disk")"
}

function test_unsuccessful_assert_exec_stderr_contains() {
  # shellcheck disable=SC2317
  function warn_command() {
    echo "ok" >&2
  }

  local expected="exit: 0"$'\n'"stderr contains: failure"
  local actual="exit: 0"$'\n'"stderr: ok"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert exec stderr contains" "$expected" "but got " "$actual")" \
    "$(assert_exec warn_command --stderr-contains "failure")"
}

function test_successful_assert_exec_stderr_not_contains() {
  # shellcheck disable=SC2317
  function warn_command() {
    echo "ok" >&2
  }

  assert_empty "$(assert_exec warn_command --stderr-not-contains "error")"
}

function test_unsuccessful_assert_exec_stderr_not_contains() {
  # shellcheck disable=SC2317
  function warn_command() {
    echo "fatal error" >&2
  }

  local expected="exit: 0"$'\n'"stderr not contains: error"
  local actual="exit: 0"$'\n'"stderr: fatal error"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert exec stderr not contains" "$expected" "but got " "$actual")" \
    "$(assert_exec warn_command --stderr-not-contains "error")"
}

function test_successful_assert_exec_interactive_prompt_flow() {
  # shellcheck disable=SC2317
  function question_command() {
    local name lang
    read -r name
    read -r lang
    echo "Your name is $name and you prefer $lang."
  }

  assert_empty "$(assert_exec question_command \
    --stdin "Chemaclass"$'\n'"Phel-Lang"$'\n' \
    --stdout-contains "Your name is Chemaclass and you prefer Phel-Lang." \
    --stdout-not-contains "Delphi" \
    --exit 0)"
}
