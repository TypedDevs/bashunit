#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

# Test error cases
function test_bashunit_assert_subcommand_no_function() {
  local output
  local exit_code
  output=$(./bashunit assert 2>&1) && exit_code=$? || exit_code=$?

  assert_contains "Error: Assert function name or command is required" "$output"
  assert_general_error "" "" "$exit_code"
}

function test_bashunit_assert_subcommand_non_existing_function() {
  local exit_code
  ./bashunit assert non_existing_function 2>&1 && exit_code=$? || exit_code=$?
  assert_command_not_found "" "" "$exit_code"
}

# args_count was 0, so `${args[-1]}` expanded to a negative subscript: a raw
# `bad array subscript` on Bash 3.x, and the run still exited 0 (#877).
function test_bashunit_assert_subcommand_without_arguments() {
  local output
  local exit_code
  output=$(./bashunit assert equals 2>&1) && exit_code=$? || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_not_contains "bad array subscript" "$output"
  assert_contains "equals" "$output"
}

function test_bashunit_assert_subcommand_without_arguments_for_a_code_assertion() {
  local output
  local exit_code
  output=$(./bashunit assert successful_code 2>&1) && exit_code=$? || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_not_contains "bad array subscript" "$output"
}

function test_bashunit_assert_subcommand_still_accepts_a_single_argument() {
  local output
  local exit_code
  output=$(./bashunit assert empty "" 2>&1) && exit_code=$? || exit_code=$?

  assert_successful_code "" "" "$exit_code"
}

function test_bashunit_assert_subcommand_failure() {
  local exit_code
  ./bashunit --no-parallel assert equals "foo" "bar" 2>&1 && exit_code=$? || exit_code=$?
  assert_general_error "" "" "$exit_code"
}

# Backward compatibility with the deprecated --assert option. These are the only
# tests that should still use it: everything else exercises `bashunit assert`.
# The form keeps working and warns; it is removed no earlier than the next major.
function test_bashunit_old_assert_option_still_works() {
  local output
  output=$(./bashunit -a equals "foo" "foo" 2>&1)
  assert_successful_code "$output"
}

function test_bashunit_old_assert_option_long_form() {
  local output
  output=$(./bashunit --assert equals "foo" "foo" 2>&1)
  assert_successful_code "$output"
}

function test_bashunit_old_assert_option_warns_that_it_is_deprecated() {
  local warnings
  warnings=$(./bashunit -a equals "foo" "foo" 2>&1 >/dev/null)

  assert_contains "Deprecated" "$warnings"
  assert_contains "bashunit assert" "$warnings"
}

function test_bashunit_new_assert_subcommand_does_not_warn() {
  local warnings
  warnings=$(./bashunit assert equals "foo" "foo" 2>&1 >/dev/null)

  assert_empty "$warnings"
}

# Test deprecation notice in help
function test_bashunit_test_help_shows_deprecation() {
  local output
  output=$(./bashunit test --help 2>&1)

  assert_contains "deprecated" "$output"
  assert_contains "bashunit assert" "$output"
}
