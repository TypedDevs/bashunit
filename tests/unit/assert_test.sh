#!/bin/bash

function test_successful_assert_equals() {
  assertEmpty "$(assert_equals "1" "1")"
}

function test_unsuccessful_assert_equals() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assert equals" "1" "but got" "2")"\
    "$(assert_equals "1" "2")"
}

function test_successful_assertEmpty() {
  assertEmpty "$(assertEmpty "")"
}

function test_unsuccessful_assertEmpty() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertEmpty" "to be empty" "but got" "1")"\
    "$(assertEmpty "1")"
}

function test_successful_assertNotEmpty() {
  assertEmpty "$(assertNotEmpty "a_random_string")"
}

function test_unsuccessful_assertNotEmpty() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertNotEmpty" "to not be empty" "but got" "")"\
    "$(assertNotEmpty "")"
}

function test_successful_assertNotEquals() {
  assertEmpty "$(assertNotEquals "1" "2")"
}

function test_unsuccessful_assertNotEquals() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertNotEquals" "1" "but got" "1")"\
    "$(assertNotEquals "1" "1")"
}

function test_successful_assertContains() {
  assertEmpty "$(assertContains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assertContains() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertContains" "GNU/Linux" "to contain" "Unix")"\
    "$(assertContains "Unix" "GNU/Linux")"
}

function test_successful_assertNotContains() {
  assertEmpty "$(assertNotContains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assertNotContains() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertNotContains" "GNU/Linux" "to not contain" "Linux")"\
    "$(assertNotContains "Linux" "GNU/Linux")"
}

function test_successful_assertMatches() {
  assertEmpty "$(assertMatches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assertMatches() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertMatches" "GNU/Linux" "to match" ".*Pinux*")"\
    "$(assertMatches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assertNotMatches() {
  assertEmpty "$(assertNotMatches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assertNotMatches() {
  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertNotMatches" "GNU/Linux" "to not match" ".*Linu*")"\
    "$(assertNotMatches ".*Linu*" "GNU/Linux")"
}

function test_successful_assertExitCode() {
  function fake_function() {
    exit 0
  }

  assertEmpty "$(assertExitCode "0" "$(fake_function)")"
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

  assertEmpty "$(assertSuccessfulCode "$(fake_function)")"
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

  assertEmpty "$(assertGeneralError "$(fake_function)")"
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
  assertEmpty "$(assertCommandNotFound "$(a_non_existing_function > /dev/null 2>&1)")"
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

  assertEmpty "$(assertArrayContains "123" "${distros[@]}")"
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

  assertEmpty "$(assertArrayNotContains "a_non_existing_element" "${distros[@]}")"
}

function test_unsuccessful_assertArrayNotContains() {
  local distros=(Ubuntu 123 Linux\ Mint)

  assert_equals\
    "$(Console::printFailedTest "Unsuccessful assertArrayNotContains" "Ubuntu 123 Linux Mint" "to not contain" "123")"\
    "$(assertArrayNotContains "123" "${distros[@]}")"
}
