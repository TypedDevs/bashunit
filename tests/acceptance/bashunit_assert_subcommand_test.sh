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

function test_bashunit_assert_subcommand_failure() {
        local exit_code
        ./bashunit --no-parallel assert equals "foo" "bar" 2>&1 && exit_code=$? || exit_code=$?
        assert_general_error "" "" "$exit_code"
}

# Test backward compatibility with --assert option
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

# Test multi-assertion mode
function test_multi_assert_exit_code_and_contains() {
        ./bashunit assert "echo 'some error' && exit 1" exit_code "1" contains "some error" 2>&1
        assert_successful_code
}

function test_multi_assert_exit_code_zero_and_output() {
        ./bashunit assert "echo 'success message'" exit_code "0" contains "success" 2>&1
        assert_successful_code
}

function test_multi_assert_multiple_output_assertions() {
        ./bashunit assert "echo 'hello world'" exit_code "0" contains "hello" contains "world" 2>&1
        assert_successful_code
}

function test_multi_assert_fails_on_exit_code_mismatch() {
        local exit_code
        ./bashunit assert "echo 'output' && exit 1" exit_code "0" 2>&1 && exit_code=$? || exit_code=$?
        assert_general_error "" "" "$exit_code"
}

function test_multi_assert_fails_on_contains_mismatch() {
        local exit_code
        ./bashunit assert "echo 'actual output'" exit_code "0" contains "expected" 2>&1 && exit_code=$? || exit_code=$?
        assert_general_error "" "" "$exit_code"
}

function test_multi_assert_missing_assertion_arg() {
        local exit_code
        local output
        output=$(./bashunit assert "echo test" exit_code 2>&1) && exit_code=$? || exit_code=$?
        assert_contains "Missing argument for assertion" "$output"
        assert_general_error "" "" "$exit_code"
}

function test_multi_assert_help_shows_multi_syntax() {
        local output
        output=$(./bashunit assert --help 2>&1)
        assert_contains "Multiple assertions on command output" "$output"
}
