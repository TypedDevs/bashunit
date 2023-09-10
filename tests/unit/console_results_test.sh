#!/bin/bash

function test_not_render_passed_tests_when_no_passed_tests_nor_assertions() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertNotMatches\
    ".*Tests:[^\n]*passed[^\n]*total.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_not_render_passed_assertions_when_no_passed_tests_nor_assertions() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertNotMatches\
    ".*Assertions:[^\n]*passed[^\n]*total.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_tests_when_passed_tests() {
  local test_passed=1
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertMatches\
    $'.*Tests:[^\n]*\e\[32m1 passed\e\[0m[^\n]*1 total.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_tests_when_passed_assertions() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=1
  local assertions_failed=0

  assertMatches\
    $'.*Tests:[^\n]*\e\[32m0 passed\e\[0m[^\n]*0 total.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_assertions_when_passed_tests() {
  local test_passed=1
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertMatches\
    $'.*Assertions:[^\n]*\e\[32m0 passed\e\[0m[^\n]*0 total.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_assertions_when_passed_assertions() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=1
  local assertions_failed=0

  assertMatches\
    $'.*Assertions:[^\n]*\e\[32m1 passed\e\[0m[^\n]*1 total.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_not_render_failed_tests_when_not_failed_tests() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertNotMatches\
    ".*Tests:[^\n]*failed[^\n]*total.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_not_render_failed_assertions_when_not_failed_tests() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertNotMatches\
    ".*Assertions:[^\n]*failed[^\n]*total.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_failed_tests_when_failed_tests() {
  local test_passed=0
  local test_failed=1
  local assertions_passed=0
  local assertions_failed=0

  assertMatches\
    $'.*Tests:[^\n]*\e\[31m1 failed\e\[0m[^\n]*1 total.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_failed_assertions_when_failed_tests() {
  local test_passed=0
  local test_failed=1
  local assertions_passed=0
  local assertions_failed=0

  assertMatches\
    $'.*Assertions:[^\n]*\e\[31m0 failed\e\[0m[^\n]*0 total.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_not_render_all_tests_passed_when_failed_tests() {
  local test_passed=0
  local test_failed=1
  local assertions_passed=0
  local assertions_failed=0

  assertNotMatches\
    ".*All tests passed.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_all_tests_passed_when_not_failed_tests() {
  local test_passed=0
  local test_failed=0
  local assertions_passed=0
  local assertions_failed=0

  assertMatches\
    $'.*\e\[42mAll tests passed\e\[0m.*'\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_total_tests_is_the_sum_of_passed_and_failed_tests() {
  local test_passed=4
  local test_failed=2
  local assertions_passed=1
  local assertions_failed=3

  assertMatches\
    ".*Tests:[^\n]*6 total.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_total_asserts_is_the_sum_of_passed_and_failed_asserts() {
  local test_passed=4
  local test_failed=2
  local assertions_passed=1
  local assertions_failed=3

  assertMatches\
    ".*Assertions:[^\n]*4 total.*"\
    "$(renderResult $test_passed $test_failed $assertions_passed $assertions_failed)"
}

function test_render_time_of_execution_when_all_assertions_passed() {
  if [[ $_OS != "OSX" ]]; then
    assertMatches\
      ".*Time taken: [[:digit:]]+ ms"\
      "$(renderResult)"
  fi
}

function test_render_time_of_execution_when_not_all_assertions_passed() {
  if [[ $_OS != "OSX" ]]; then
    assertMatches\
      ".*Time taken: [[:digit:]]+ ms"\
      "$(renderResult)"
  fi
}
