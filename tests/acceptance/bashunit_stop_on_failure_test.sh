#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
        TEST_ENV_FILE_STOP_ON_FAILURE="tests/acceptance/fixtures/.env.stop_on_failure"
}

function test_bashunit_when_stop_on_failure_option() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

        assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
}

function test_bashunit_when_stop_on_failure_env() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

        assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
}

function test_different_snapshots_matches() {
        bashunit::todo "The different snapshots for these tests should also be identical, option to choose snapshot name?"
}

function test_bashunit_when_stop_on_failure_env_simple_output() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

        assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file" --simple)"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file" --simple)"
}
