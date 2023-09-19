#!/bin/bash

TESTS_PASSED=0
TESTS_FAILED=0
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
DUPLICATED_FOUND=false

function test_not_render_passed_tests_when_no_passed_tests_nor_assertions() {
  local TESTS_PASSED=0
  local ASSERTIONS_PASSED=0

  assertNotMatches\
    "Tests:[^\n]*passed[^\n]*total"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_not_render_passed_assertions_when_no_passed_tests_nor_assertions() {
  local TESTS_PASSED=0
  local ASSERTIONS_PASSED=0

  assertNotMatches\
    "Assertions:[^\n]*passed[^\n]*total"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_passed_tests_when_passed_tests() {
  local TESTS_PASSED=1

  assertMatches\
    $'Tests:[^\n]*\e\[32m1 passed\e\[0m[^\n]*total'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_passed_tests_when_passed_assertions() {
  local TESTS_PASSED=0
  local ASSERTIONS_PASSED=1

  assertMatches\
    $'Tests:[^\n]*\e\[32m0 passed\e\[0m[^\n]*total'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_passed_assertions_when_passed_tests() {
  local TESTS_PASSED=1
  local ASSERTIONS_PASSED=0

  assertMatches\
    $'Assertions:[^\n]*\e\[32m0 passed\e\[0m[^\n]*total'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_passed_assertions_when_passed_assertions() {
  local ASSERTIONS_PASSED=1

  assertMatches\
    $'Assertions:[^\n]*\e\[32m1 passed\e\[0m[^\n]*total'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_not_render_failed_tests_when_not_failed_tests() {
  local TESTS_FAILED=0

  assertNotMatches\
    "Tests:[^\n]*failed[^\n]*total"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_not_render_failed_assertions_when_not_failed_tests() {
  local TESTS_FAILED=0

  assertNotMatches\
    "Assertions:[^\n]*failed[^\n]*total"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_failed_tests_when_failed_tests() {
  local TESTS_FAILED=1

  assertMatches\
    $'Tests:[^\n]*\e\[31m1 failed\e\[0m[^\n]*total'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_failed_assertions_when_failed_tests() {
  local TESTS_FAILED=1
  local ASSERTIONS_FAILED=0

  assertMatches\
    $'Assertions:[^\n]*\e\[31m0 failed\e\[0m[^\n]*total'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_not_render_all_tests_passed_when_failed_tests() {
  local TESTS_FAILED=1

  assertNotMatches\
    "All tests passed"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_all_tests_passed_when_not_failed_tests() {
  local TESTS_FAILED=0

  assertMatches\
    $'\e\[42mAll tests passed\e\[0m'\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_total_tests_is_the_sum_of_passed_and_failed_tests() {
  local TESTS_PASSED=4
  local TESTS_FAILED=2

  assertMatches\
    "Tests:[^\n]*6 total"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_total_asserts_is_the_sum_of_passed_and_failed_asserts() {
  local ASSERTIONS_PASSED=1
  local ASSERTIONS_FAILED=3

  assertMatches\
    "Assertions:[^\n]*4 total"\
    "$(Console::renderResult $TESTS_PASSED $TESTS_FAILED $ASSERTIONS_PASSED $ASSERTIONS_FAILED $DUPLICATED_FOUND)"
}

function test_render_time_of_execution_when_all_assertions_passed() {
  if [[ $_OS != "OSX" ]]; then
    assertMatches\
      "Time taken: [[:digit:]]+ ms"\
      "$(Console::renderResult)"
  fi
}

function test_render_time_of_execution_when_not_all_assertions_passed() {
  if [[ $_OS != "OSX" ]]; then
    assertMatches\
      "Time taken: [[:digit:]]+ ms"\
      "$(Console::renderResult)"
  fi
}

function test_should_not_render_time_of_execution_when_all_assertions_passed_on_mac() {
  if [[ $_OS == "OSX" ]]; then
    assertNotMatches\
      "Time taken: [[:digit:]]+ ms"\
      "$(Console::renderResult)"
  fi
}

function test_should_not_render_time_of_execution_when_not_all_assertions_passed_on_mac() {
  if [[ $_OS == "OSX" ]]; then
    assertNotMatches\
      "Time taken: [[:digit:]]+ ms"\
      "$(Console::renderResult)"
  fi
}
