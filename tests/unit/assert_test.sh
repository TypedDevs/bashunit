#!/bin/bash
SUCCESSFUL_EMPTY_MESSAGE=""

function test_successful_assertEquals() {
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertEquals "1" "1")"
  assertExitCode "0" "$(assertEquals "1" "1")"
}

function test_unsuccessful_assertEquals() {
  assertEquals "$(printFailedTest "Unsuccessful assertEquals" "1" "but got" "2")"\
  "$(assertEquals "1" "2")"

  assertExitCode "1" "$(assertEquals "1" "2")"
}

function test_successful_assertContains() {
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertContains "Linux" "GNU/Linux")"
  assertExitCode "0" "$(assertContains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assertContains() {
  assertEquals "$(printFailedTest "Unsuccessful assertContains" "GNU/Linux" "to contain" "Unix")"\
  "$(assertContains "Unix" "GNU/Linux")"

  assertExitCode "1" "$(assertContains "Unix" "GNU/Linux")"
}

function test_successful_assertNotContains() {
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertNotContains "Linus" "GNU/Linux")"
  assertExitCode "0" "$(assertNotContains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assertNotContains() {
  assertEquals "$(printFailedTest "Unsuccessful assertNotContains" "GNU/Linux" "to not contain" "Linux")"\
  "$(assertNotContains "Linux" "GNU/Linux")"

  assertExitCode "1" "$(assertNotContains "Linux" "GNU/Linux")"
}

function test_successful_assertMatches() {
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertMatches ".*Linu*" "GNU/Linux")"
  assertExitCode "0" "$(assertMatches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assertMatches() {
  assertEquals "$(printFailedTest "Unsuccessful assertMatches" "GNU/Linux" "to match" ".*Pinux*")"\
  "$(assertMatches ".*Pinux*" "GNU/Linux")"

  assertExitCode "1" "$(assertMatches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assertNotMatches() {
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertNotMatches ".*Pinux*" "GNU/Linux")"
  assertExitCode "0" "$(assertNotMatches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assertNotMatches() {
  assertEquals\
    "$(printFailedTest "Unsuccessful assertNotMatches" "GNU/Linux" "to not match" ".*Linu*")"\
    "$(assertNotMatches ".*Linu*" "GNU/Linux")"

    assertExitCode "1" "$(assertNotMatches ".*Linu*" "GNU/Linux")"
}

function test_successful_assertExitCode() {
  function fake_function() {
    exit 0
  }
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertExitCode "0" "$(fake_function)")"

  assertExitCode "0" "$(fake_function)"
}

function test_unsuccessful_assertExitCode() {
  function fake_function() {
    exit 1
  }
  assertEquals\
    "$(printFailedTest "Unsuccessful assertExitCode" "1" "to be" "0")"\
    "$(assertExitCode "0" "$(fake_function)")"

  assertExitCode "1" "$(assertExitCode "0" "$(fake_function)")"
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
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertSuccessfulCode "$(fake_function)")"

  assertSuccessfulCode "$(fake_function)"
}

function test_unsuccessful_assertSuccessfulCode() {
  function fake_function() {
    return 2
  }
  assertEquals\
    "$(printFailedTest "Unsuccessful assertSuccessfulCode" "2" "to be exactly" "0")"\
    "$(assertSuccessfulCode "$(fake_function)")"

  assertExitCode "1" "$(assertSuccessfulCode "$(fake_function)")"
}

function test_successful_assertGeneralError() {
  function fake_function() {
    return 1
  }
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertGeneralError "$(fake_function)")"

  assertGeneralError "$(fake_function)"
}

function test_unsuccessful_assertGeneralError() {
  function fake_function() {
    return 2
  }
  assertEquals\
    "$(printFailedTest "Unsuccessful assertGeneralError" "2" "to be exactly" "1")"\
    "$(assertGeneralError "$(fake_function)")"

  assertExitCode "1" "$(assertGeneralError "$(fake_function)")"
}

function test_successful_assertCommandNotFound() {
  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertCommandNotFound "$(a_non_existing_function)")"

  assertExitCode "0" "$(assertCommandNotFound "$(a_non_existing_function)")"
}

function test_unsuccessful_assertCommandNotFound() {
  function fake_function() {
    return 0
  }
  assertEquals\
    "$(printFailedTest "Unsuccessful assertCommandNotFound" "0" "to be exactly" "127")"\
    "$(assertCommandNotFound "$(fake_function)")"

  assertExitCode "1" "$(assertCommandNotFound "$(fake_function)")"
}

unset SUCCESSFUL_EMPTY_MESSAGE
