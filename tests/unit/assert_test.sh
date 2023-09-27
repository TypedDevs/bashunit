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

function test_successful_assertExitCode() {
  function fake_function() {
    exit 0
  }

  assert_empty "$(assertExitCode "0" "$(fake_function)")"
}

function test_unsuccessful_assertExitCode() {
  function fake_function() {
    exit 1
  }

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertExitCode" "1" "to be" "0")"\
    "$(assertExitCode "0" "$(fake_function)")"
}

function test_successful_return_assertExitCode() {
  function fake_function() {
    return 0
  }

  fake_function

  assertExitCode "0"
}

function test_unsuccessful_return_assertExitCode() {
  function fake_function() {
    return 1
  }

  fake_function

  assertExitCode "1"
}

function test_successful_assertSuccessfulCode() {
  function fake_function() {
    return 0
  }

  assert_empty "$(assertSuccessfulCode "$(fake_function)")"
}

function test_unsuccessful_assertSuccessfulCode() {
  function fake_function() {
    return 2
  }

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertSuccessfulCode" "2" "to be exactly" "0")"\
    "$(assertSuccessfulCode "$(fake_function)")"
}

function test_successful_assertGeneralError() {
  function fake_function() {
    return 1
  }

  assert_empty "$(assertGeneralError "$(fake_function)")"
}

function test_unsuccessful_assertGeneralError() {
  function fake_function() {
    return 2
  }

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertGeneralError" "2" "to be exactly" "1")"\
    "$(assertGeneralError "$(fake_function)")"
}

function test_successful_assertCommandNotFound() {
  assert_empty "$(assertCommandNotFound "$(a_non_existing_function > /dev/null 2>&1)")"
}

function test_unsuccessful_assertCommandNotFound() {
  function fake_function() {
    return 0
  }

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertCommandNotFound" "0" "to be exactly" "127")"\
    "$(assertCommandNotFound "$(fake_function)")"
}

function test_successful_assertArrayContains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assertArrayContains "123" "${distros[@]}")"
}

function test_unsuccessful_assertArrayContains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_equals\
    "$(Console::printFailedTest \
      "Unsuccessful assertArrayContains"\
      "Ubuntu 123 Linux Mint"\
      "to contain"\
      "non_existing_element")"\
    "$(assertArrayContains "non_existing_element" "${distros[@]}")"
}

function test_successful_assertArrayNotContains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_empty "$(assertArrayNotContains "a_non_existing_element" "${distros[@]}")"
}

function test_unsuccessful_assertArrayNotContains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertArrayNotContains" "Ubuntu 123 Linux Mint" "to not contain" "123")"\
    "$(assertArrayNotContains "123" "${distros[@]}")"
}
