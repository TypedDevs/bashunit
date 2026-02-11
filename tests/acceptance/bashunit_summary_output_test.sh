#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_skipped_tests_not_displayed_without_flag() {
        local output
        output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" \
                "tests/acceptance/bashunit_init_test.sh" 2>&1) || true

        assert_not_contains "There was 1 skipped test:" "$output"
}

function test_incomplete_tests_not_displayed_without_flag() {
        local output
        output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" \
                "tests/acceptance/bashunit_execution_error_test.sh" 2>&1) || true

        assert_not_contains "There was 1 incomplete test:" "$output"
}

function test_skipped_tests_displayed_with_show_skipped_flag() {
        local output
        output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel --simple --show-skipped \
                "tests/acceptance/bashunit_init_test.sh" 2>&1) || true

        assert_contains "There was 1 skipped test:" "$output"
        assert_contains "Bashunit init updates env" "$output"
}

function test_incomplete_tests_displayed_with_show_incomplete_flag() {
        local output
        output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel --simple --show-incomplete \
                "tests/acceptance/bashunit_execution_error_test.sh" 2>&1) || true

        assert_contains "There was 1 incomplete test:" "$output"
        assert_contains "Add snapshots with regex" "$output"
}

function test_both_flags_can_be_used_together() {
        local output
        output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel --simple --show-skipped --show-incomplete \
                "tests/acceptance/bashunit_fail_test.sh" "tests/acceptance/bashunit_init_test.sh" 2>&1) || true

        assert_contains "incomplete test" "$output"
        assert_contains "skipped test" "$output"
}
