#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_a_test_returns_non_zero() {
        local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_returns_non_zero.sh

        assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
        assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}
