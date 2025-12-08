#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

# Test basic assert subcommand functionality
function test_bashunit_assert_subcommand_equals() {
  ./bashunit assert equals "foo" "foo"
  assert_successful_code
}

function test_bashunit_assert_subcommand_same() {
  ./bashunit assert same "1" "1"
  assert_successful_code
}

function test_bashunit_assert_subcommand_contains() {
  ./bashunit assert contains "world" "hello world"
  assert_successful_code
}

function test_bashunit_assert_subcommand_without_prefix() {
  ./bashunit assert equals "bar" "bar"
  assert_successful_code
}

# Test help functionality
function test_bashunit_assert_subcommand_help_short() {
  local output
  output=$(./bashunit assert -h 2>&1)

  assert_contains "Usage: bashunit assert" "$output"
  assert_contains "Run a standalone assertion" "$output"
  assert_successful_code "$(./bashunit assert -h)"
}

function test_bashunit_assert_subcommand_help_long() {
  local output
  output=$(./bashunit assert --help 2>&1)

  assert_contains "Usage: bashunit assert" "$output"
  assert_contains "Examples:" "$output"
  assert_successful_code "$(./bashunit assert --help)"
}

# Test error cases
function test_bashunit_assert_subcommand_no_function() {
  local output
  output=$(./bashunit assert 2>&1)

  assert_contains "Error: Assert function name is required" "$output"
  assert_general_error "$(./bashunit assert)"
}

function test_bashunit_assert_subcommand_non_existing_function() {
  assert_command_not_found "$(./bashunit assert non_existing_function)"
}

function test_bashunit_assert_subcommand_failure() {
  assert_general_error "$(./bashunit --no-parallel assert equals "foo" "bar")"
}

# Test backward compatibility with --assert option
function test_bashunit_old_assert_option_still_works() {
  ./bashunit -a equals "foo" "foo"
  assert_successful_code
}

function test_bashunit_old_assert_option_long_form() {
  ./bashunit --assert equals "foo" "foo"
  assert_successful_code
}

# Test deprecation notice in help
function test_bashunit_test_help_shows_deprecation() {
  local output
  output=$(./bashunit test --help 2>&1)

  assert_contains "deprecated" "$output"
  assert_contains "bashunit assert" "$output"
}

# Test assert subcommand is in main help
function test_bashunit_main_help_includes_assert() {
  local output
  output=$(./bashunit --help 2>&1)

  assert_contains "assert <fn> <args>" "$output"
}
