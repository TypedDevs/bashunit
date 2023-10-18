#!/bin/bash

function test_successful_assert_match_snapshot() {
  assert_empty "$(assert_match_snapshot "Hello World!")"
}

function test_unsuccessful_assert_match_snapshot() {
  local expected
  expected="$(printf "${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: Unsuccessful assert match snapshot
    ${_COLOR_FAINT}Expected to match the snapshot${_COLOR_DEFAULT}
    ${_COLOR_FAILED}[-Actual-]${_COLOR_PASSED}{+Expected+}${_COLOR_DEFAULT} snapshot${_COLOR_FAILED}[-text-]${_COLOR_DEFAULT}")"

  local actual
  actual="$(assert_match_snapshot "Expected snapshot")"

  # Remove color codes using sed
  clean_expected=$(echo -e "$expected" | sed "s/\x1B\[[0-9;]*[JKmsu]//g")
  clean_actual=$(echo -e "$actual" | sed "s/\x1B\[[0-9;]*[JKmsu]//g")


  assert_equals "$clean_expected" "$clean_actual"
}
