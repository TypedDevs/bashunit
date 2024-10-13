#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_a_execution_error() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh
  local fixture_start fixture_end
  local color_default color_red color_dim color_bold

  color_default="$(sgr 0)"
  color_bold="$(sgr 1)"
  color_dim="$(sgr 2)"
  color_red="$(sgr 31)"

  function format_fail_title() {
    printf "\n%s%s%s%s" "${color_red}" "$1" "${color_default}" "$2"
  }

  function format_expect_title() {
    printf "\n    %s%s%s" "${color_dim}" "$1" "${color_default}"
  }

  function format_expect_value() {
    printf " %s%s%s" "${color_bold}" "$1" "${color_default}"
  }

  function format_summary_title() {
    printf "\n%s%s%s" "${color_dim}" "$1" "${color_default}"
  }

  function format_summary_value() {
    printf " %s%s%s%s" "${color_red}" "$1" "${color_default}" "$2"
  }

  fixture_start=$(
    printf "${color_bold}%s${color_default}\n" "Running ./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh"
    format_fail_title "✗ Failed" ": Error"
    format_expect_title "Expected"
    format_expect_value "'127'"
    format_expect_title "to be exactly"
    format_expect_value "'1'"
  )
  fixture_end=$(
    format_summary_title "Tests:     "
    format_summary_value "1 failed" ", 1 total"
    format_summary_title "Assertions:"
    format_summary_value "1 failed" ", 1 total"
  )

  todo "Add snapshots with regex to assert this test (part of the error message is localized)"
  todo "Add snapshots with simple/verbose modes as in bashunit_pass_test and bashunit_fail_test"

  # shellcheck disable=SC2155
  local actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
  assert_contains "$fixture_start" "$actual"
  assert_contains "$fixture_end" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}
