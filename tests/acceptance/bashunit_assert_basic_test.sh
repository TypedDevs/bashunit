#!/usr/bin/env bash
set -euo pipefail

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
  assert_contains "Run standalone assertion" "$output"
  assert_successful_code "$(./bashunit assert -h)"
}

function test_bashunit_assert_subcommand_help_long() {
  local output
  output=$(./bashunit assert --help 2>&1)

  assert_contains "Usage: bashunit assert" "$output"
  assert_contains "Single assertion:" "$output"
  assert_successful_code "$(./bashunit assert --help)"
}

# Test assert subcommand is in main help
function test_bashunit_main_help_includes_assert() {
  local output
  output=$(./bashunit --help 2>&1)

  assert_contains "assert <fn> <args>" "$output"
}

function test_multi_assert_help_shows_multi_syntax() {
  local output
  output=$(./bashunit assert --help 2>&1)
  assert_contains "Multiple assertions on command output" "$output"
}
