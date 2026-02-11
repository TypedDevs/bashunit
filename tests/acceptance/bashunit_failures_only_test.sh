#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_failures_only_suppresses_passed_tests_in_detailed_mode() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
        local output

        output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --failures-only "$test_file" 2>&1)

        assert_not_contains "Passed" "$output"
        assert_contains "Tests:" "$output"
        assert_contains "4 passed" "$output"
}

function test_failures_only_shows_failures() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
        local output

        output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --failures-only "$test_file" 2>&1) || true

        assert_contains "Failed" "$output"
        assert_contains "Tests:" "$output"
}

function test_failures_only_suppresses_passed_tests_in_simple_mode() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
        local output

        output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" --failures-only "$test_file" 2>&1)

        # Should NOT contain dots for passed tests (dots appear before summary)
        # The output should only have the summary line, not progress dots
        assert_not_contains "...." "$output"
        assert_contains "Tests:" "$output"
}

function test_failures_only_shows_correct_counts_in_summary() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
        local output

        output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --failures-only "$test_file" 2>&1)

        # Summary should show passed count even though output was suppressed
        assert_contains "4 passed" "$output"
        assert_contains "4 total" "$output"
}

function test_failures_only_suppresses_file_headers() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
        local output

        output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --failures-only "$test_file" 2>&1)

        assert_not_contains "Running" "$output"
}

function test_failures_only_via_env_variable() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
        local output

        output=$(BASHUNIT_FAILURES_ONLY=true ./bashunit --no-parallel --skip-env-file "$test_file" 2>&1)

        assert_not_contains "Passed" "$output"
        assert_contains "4 passed" "$output"
}
