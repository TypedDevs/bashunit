#!/usr/bin/env bash
# shellcheck disable=SC2155
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_a_execution_error() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh
  local color_default="$(sgr 0)"
  local color_bold="$(sgr 1)"
  local color_dim="$(sgr 2)"
  local color_red="$(sgr 31)"

  function format_summary_title() {
    printf "\n%s%s%s" "${color_dim}" "$1" "${color_default}"
  }

  function format_summary_value() {
    printf " %s%s%s%s" "${color_red}" "$1" "${color_default}" "$2"
  }

  local fixture_start=$(
    printf "%sRunning ./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh%s\n" \
      "${color_bold}" "${color_default}"
    printf "%s✗ Error%s: Error\n" "${color_red}" "${color_default}"
    printf "    %sline 4: invalid_function_name: command not found%s\n" "${color_dim}" "${color_default}"
  )
  local fixture_end=$(
    format_summary_title "Tests:     "
    format_summary_value "1 failed" ", 1 total"
    format_summary_title "Assertions:"
    format_summary_value "0 failed" ", 0 total"
  )

  todo "Add snapshots with regex to assert this test (part of the error message is localized)"
  todo "Add snapshots with simple/verbose modes as in bashunit_pass_test and bashunit_fail_test"

  local actual="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  assert_contains "$fixture_start" "$actual"
  assert_contains "$fixture_end" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}
