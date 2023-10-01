#!/bin/bash

function test_successful_assert_equals() {
  assert_empty "$(assert_equals "1" "1")"
}

function test_unsuccessful_assert_equals() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert equals" "1" "but got" "2")"\
    "$(assert_equals "1" "2")"
}

function test_successful_assert_empty() {
  assert_empty "$(assert_empty "")"
}

function test_unsuccessful_assert_empty() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert empty" "to be empty" "but got" "1")"\
    "$(assert_empty "1")"
}

function test_successful_assert_not_empty() {
  assert_empty "$(assert_not_empty "a_random_string")"
}

function test_unsuccessful_assert_not_empty() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert not empty" "to not be empty" "but got" "")"\
    "$(assert_not_empty "")"
}

function test_successful_assert_not_equals() {
  assert_empty "$(assert_not_equals "1" "2")"
}

function test_unsuccessful_assert_not_equals() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert not equals" "1" "but got" "1")"\
    "$(assert_not_equals "1" "1")"
}

function test_successful_assert_contains() {
  assert_empty "$(assert_contains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assert_contains() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert contains" "GNU/Linux" "to contain" "Unix")"\
    "$(assert_contains "Unix" "GNU/Linux")"
}

function test_successful_assert_not_contains() {
  assert_empty "$(assert_not_contains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assert_not_contains() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert not contains" "GNU/Linux" "to not contain" "Linux")"\
    "$(assert_not_contains "Linux" "GNU/Linux")"
}

function test_successful_assert_matches() {
  assert_empty "$(assert_matches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assert_matches() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert matches" "GNU/Linux" "to match" ".*Pinux*")"\
    "$(assert_matches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assert_not_matches() {
  assert_empty "$(assert_not_matches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assert_not_matches() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert not matches" "GNU/Linux" "to not match" ".*Linu*")"\
    "$(assert_not_matches ".*Linu*" "GNU/Linux")"
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

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert exit code" "1" "to be" "0")"\
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

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert successful code" "2" "to be exactly" "0")"\
    "$(assert_successful_code "$(fake_function)")"
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

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert general error" "2" "to be exactly" "1")"\
    "$(assert_general_error "$(fake_function)")"
}

function test_successful_assert_command_not_found() {
  assert_empty "$(assert_command_not_found "$(a_non_existing_function > /dev/null 2>&1)")"
}

function test_unsuccessful_assert_command_not_found() {
  function fake_function() {
    return 0
  }

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert command not found" "0" "to be exactly" "127")"\
    "$(assert_command_not_found "$(fake_function)")"
}

function test_successful_assert_array_contains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assert_array_contains "123" "${distros[@]}")"
}

function test_unsuccessful_assert_array_contains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_equals\
    "$(Console::printFailedTest \
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

  assert_equals\
    "$(Console::printFailedTest\
      "Unsuccessful assert array not contains" "Ubuntu 123 Linux Mint" "to not contain" "123")"\
    "$(assert_array_not_contains "123" "${distros[@]}")"
}

function test_successful_assert_file_exists() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_empty "$(assert_file_exists "$a_file")"

  unset $a_file
}

function test_unsuccessful_assert_file_exists() {
  local a_file="a_random_file_that_will_not_exist"

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert file exists" "$a_file" "to exist but" "do not exist")"\
    "$(assert_file_exists "$a_file")"

  unset $a_file
}

function test_assert_file_exists_should_not_work_with_folders() {
  local a_dir
  a_dir="$(dirname "${BASH_SOURCE[0]}")"

  assert_equals\
    "$(Console::printFailedTest \
      "Assert file exists should not work with folders" "$a_dir" "to exist but" "do not exist")"\
    "$(assert_file_exists "$a_dir")"

  unset $a_dir
}

function test_successful_assert_file_not_exists() {
  local a_file="a_random_file_that_will_not_exist"

  assert_empty "$(assert_file_not_exists "$a_file")"

  unset $a_file
}

function test_unsuccessful_assert_file_not_exists() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert file not exists" "$a_file" "to not exist but" "the file exists")"\
    "$(assert_file_not_exists "$a_file")"

  unset $a_file
}

function test_successful_assert_is_file() {
  local a_file
  a_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  assert_empty "$(assert_is_file "$a_file")"

  unset $a_file
}

function test_unsuccessful_assert_is_file() {
  local a_file="a_random_file_that_will_not_exist"

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert is file" "$a_file" "to be a file" "but is not a file")"\
    "$(assert_is_file "$a_file")"

  unset $a_file
}
