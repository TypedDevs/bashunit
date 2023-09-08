#!/bin/bash

function test_successful_assertEquals() {
  assertEquals "$(printSuccessfulTest "Successful assertEquals")"\
  "$(assertEquals "1" "1")"
}

function test_unsuccessful_assertEquals() {
  assertEquals "$(printFailedTest "Unsuccessful assertEquals" "1" "but got" "2")"\
  "$(assertEquals "1" "2")"
}

function testCamelCase() {
  assertEquals "$(printSuccessfulTest "CamelCase")" "$(assertEquals "1" "1")"
}

function test_multiple_asserts() {
  assertEquals "1" "1" "1 equals 1"
  assertEquals "2" "2" "2 equals 2"
  assertEquals "3" "3" "3 equals 3"
  assertEquals "4" "4" "4 equals 4"
}

function test_successful_assertContains() {
  assertEquals "$(printSuccessfulTest "Successful assertContains")"\
  "$(assertContains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assertContains() {
  assertEquals "$(printFailedTest "Unsuccessful assertContains" "GNU/Linux" "to contain" "Unix")"\
  "$(assertContains "Unix" "GNU/Linux")"
}

function test_successful_assertNotContains() {
  assertEquals "$(printSuccessfulTest "Successful assertNotContains")"\
  "$(assertNotContains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assertNotContains() {
  assertEquals "$(printFailedTest "Unsuccessful assertNotContains" "GNU/Linux" "to not contain" "Linux")"\
  "$(assertNotContains "Linux" "GNU/Linux")"
}

function test_successful_assertMatches() {
  assertEquals "$(printSuccessfulTest "Successful assertMatches")"\
   "$(assertMatches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assertMatches() {
  assertEquals "$(printFailedTest "Unsuccessful assertMatches" "GNU/Linux" "to match" ".*Pinux*")"\
  "$(assertMatches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assertNotMatches() {
  assertEquals "$(printSuccessfulTest "Successful assertNotMatches")" \
  "$(assertNotMatches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assertNotMatches() {
  assertEquals "$(printFailedTest "Unsuccessful assertNotMatches" "GNU/Linux" "to not match" ".*Linu*")"\
  "$(assertNotMatches ".*Linu*" "GNU/Linux")"
}
