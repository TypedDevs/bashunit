#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
        sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_bashunit_when_tear_down_sources_nonexistent_file() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_sources_nonexistent_file.sh

        local actual_raw
        set +e
        actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
        set -e

        local actual
        actual="$(printf "%s" "$actual_raw" | strip_ansi)"

        assert_contains "failed" "$actual"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_set_up_before_script_sources_nonexistent_file() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_setup_before_script_sources_nonexistent_file.sh

        local actual_raw
        set +e
        actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
        set -e

        local actual
        actual="$(printf "%s" "$actual_raw" | strip_ansi)"

        assert_contains "failed" "$actual"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_tear_down_after_script_sources_nonexistent_file() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_after_script_sources_nonexistent_file.sh

        local actual_raw
        set +e
        actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
        set -e

        local actual
        actual="$(printf "%s" "$actual_raw" | strip_ansi)"

        assert_contains "failed" "$actual"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}
