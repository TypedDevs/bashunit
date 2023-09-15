#!/bin/bash

SUCCESSFUL_EMPTY_MESSAGE=""

function test_successful_assertEquals() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertEquals "1" "1")"
}

function test_unsuccessful_assertEquals() {
  function addTestsFailed() {
    return
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertEquals" "1" "but got" "2")"\
    "$(assertEquals "1" "2")"
}

function test_successful_assertNotEquals() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertNotEquals "1" "2")"
}

function test_unsuccessful_assertNotEquals() {
  function addTestsFailed() {
    return
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertNotEquals" "1" "but got" "1")"\
    "$(assertNotEquals "1" "1")"
}

function test_successful_assertContains() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertContains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assertContains() {
  function addTestsFailed() {
    return
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertContains" "GNU/Linux" "to contain" "Unix")"\
    "$(assertContains "Unix" "GNU/Linux")"
}

function test_successful_assertNotContains() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertNotContains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assertNotContains() {
  function addTestsFailed() {
    return
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertNotContains" "GNU/Linux" "to not contain" "Linux")"\
    "$(assertNotContains "Linux" "GNU/Linux")"
}

function test_successful_assertMatches() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertMatches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assertMatches() {
  function addTestsFailed() {
    return
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertMatches" "GNU/Linux" "to match" ".*Pinux*")"\
    "$(assertMatches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assertNotMatches() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertNotMatches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assertNotMatches() {
  function addTestsFailed() {
    return
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertNotMatches" "GNU/Linux" "to not match" ".*Linu*")"\
    "$(assertNotMatches ".*Linu*" "GNU/Linux")"
}

function test_successful_assertExitCode() {
  function addTestsSuccessful() {
    return
  }

  function fake_function() {
    exit 0
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertExitCode "0" "$(fake_function)")"
}

function test_unsuccessful_assertExitCode() {
  function addTestsFailed() {
    return
  }

  function fake_function() {
    exit 1
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertExitCode" "1" "to be" "0")"\
    "$(assertExitCode "0" "$(fake_function)")"
}

function test_successful_return_assertExitCode() {
  function addTestsSuccessful() {
    return
  }

  function fake_function() {
    return 0
  }

  fake_function

  assertExitCode "0"
}

function test_unsuccessful_return_assertExitCode() {
  function addTestsFailed() {
    return
  }

  function fake_function() {
    return 1
  }

  fake_function

  assertExitCode "1"
}

function test_successful_assertSuccessfulCode() {
  function addTestsSuccessful() {
    return
  }

  function fake_function() {
    return 0
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertSuccessfulCode "$(fake_function)")"
}

function test_unsuccessful_assertSuccessfulCode() {
  function addTestsFailed() {
    return
  }

  function fake_function() {
    return 2
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertSuccessfulCode" "2" "to be exactly" "0")"\
    "$(assertSuccessfulCode "$(fake_function)")"
}

function test_successful_assertGeneralError() {
  function addTestsSuccessful() {
    return
  }

  function fake_function() {
    return 1
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertGeneralError "$(fake_function)")"
}

function test_unsuccessful_assertGeneralError() {
  function addTestsFailed() {
    return
  }

  function fake_function() {
    return 2
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertGeneralError" "2" "to be exactly" "1")"\
    "$(assertGeneralError "$(fake_function)")"
}

function test_successful_assertCommandNotFound() {
  function addTestsSuccessful() {
    return
  }

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertCommandNotFound "$(a_non_existing_function > /dev/null 2>&1)")"
}

function test_unsuccessful_assertCommandNotFound() {
  function addTestsFailed() {
    return
  }

  function fake_function() {
    return 0
  }

  assertEquals\
    "$(printFailedTest "Unsuccessful assertCommandNotFound" "0" "to be exactly" "127")"\
    "$(assertCommandNotFound "$(fake_function)")"
}

function test_successful_assertArrayContains() {
  function addTestsSuccessful() {
    return
  }

  local distros=(Ubuntu 123 Linux\ Mint)

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertArrayContains "123" "${distros[@]}")"
}

function test_unsuccessful_assertArrayContains() {
  function addTestsFailed() {
    return
  }

  local distros=(Ubuntu 123 Linux\ Mint)

  assertEquals\
    "$(printFailedTest "Unsuccessful assertArrayContains" "Ubuntu 123 Linux Mint" "to contain" "non_existing_element")"\
    "$(assertArrayContains "non_existing_element" "${distros[@]}")"
}

function test_successful_assertArrayNotContains() {
  function addTestsSuccessful() {
    return
  }

  local distros=(Ubuntu 123 Linux\ Mint)

  assertEquals "$SUCCESSFUL_EMPTY_MESSAGE" "$(assertArrayNotContains "a_non_existing_element" "${distros[@]}")"
}

function test_unsuccessful_assertArrayNotContains() {
  function addTestsFailed() {
    return
  }

  local distros=(Ubuntu 123 Linux\ Mint)

  assertEquals\
    "$(printFailedTest "Unsuccessful assertArrayNotContains" "Ubuntu 123 Linux Mint" "to not contain" "123")"\
    "$(assertArrayNotContains "123" "${distros[@]}")"
}
