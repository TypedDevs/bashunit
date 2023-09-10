#!/bin/bash

tests_passed=0
tests_failed=0
assertions_passed=0
assertions_failed=0

function test_not_render_passed_tests_when_no_passed_tests_nor_assertions() {
  local tests_passed=0
  local assertions_passed=0

  assertNotMatches\
    "Tests:[^\n]*passed[^\n]*total"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_not_render_passed_assertions_when_no_passed_tests_nor_assertions() {
  local tests_passed=0
  local assertions_passed=0

  assertNotMatches\
    "Assertions:[^\n]*passed[^\n]*total"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_tests_when_passed_tests() {
  local tests_passed=1

  assertMatches\
    $'Tests:[^\n]*\e\[32m1 passed\e\[0m[^\n]*total'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_tests_when_passed_assertions() {
  local tests_passed=0
  local assertions_passed=1

  assertMatches\
    $'Tests:[^\n]*\e\[32m0 passed\e\[0m[^\n]*total'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_assertions_when_passed_tests() {
  local tests_passed=1
  local assertions_passed=0

  assertMatches\
    $'Assertions:[^\n]*\e\[32m0 passed\e\[0m[^\n]*total'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_passed_assertions_when_passed_assertions() {
  local assertions_passed=1

  assertMatches\
    $'Assertions:[^\n]*\e\[32m1 passed\e\[0m[^\n]*total'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_not_render_failed_tests_when_not_failed_tests() {
  local tests_failed=0

  assertNotMatches\
    "Tests:[^\n]*failed[^\n]*total"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_not_render_failed_assertions_when_not_failed_tests() {
  local tests_failed=0

  assertNotMatches\
    "Assertions:[^\n]*failed[^\n]*total"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_failed_tests_when_failed_tests() {
  local tests_failed=1

  assertMatches\
    $'Tests:[^\n]*\e\[31m1 failed\e\[0m[^\n]*total'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_failed_assertions_when_failed_tests() {
  local tests_failed=1
  local assertions_failed=0

  assertMatches\
    $'Assertions:[^\n]*\e\[31m0 failed\e\[0m[^\n]*total'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_not_render_all_tests_passed_when_failed_tests() {
  local tests_failed=1

  assertNotMatches\
    "All tests passed"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_all_tests_passed_when_not_failed_tests() {
  local tests_failed=0

  assertMatches\
    $'\e\[42mAll tests passed\e\[0m'\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_total_tests_is_the_sum_of_passed_and_failed_tests() {
  local tests_passed=4
  local tests_failed=2

  assertMatches\
    "Tests:[^\n]*6 total"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_total_asserts_is_the_sum_of_passed_and_failed_asserts() {
  local assertions_passed=1
  local assertions_failed=3

  assertMatches\
    "Assertions:[^\n]*4 total"\
    "$(renderResult $tests_passed $tests_failed $assertions_passed $assertions_failed)"
}

function test_render_time_of_execution_when_all_assertions_passed() {
  if [[ $_OS != "OSX" ]]; then
    assertMatches\
      "Time taken: [[:digit:]]+ ms"\
      "$(renderResult)"
  fi
}

function test_render_time_of_execution_when_not_all_assertions_passed() {
  if [[ $_OS != "OSX" ]]; then
    assertMatches\
      "Time taken: [[:digit:]]+ ms"\
      "$(renderResult)"
  fi
}
