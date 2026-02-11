#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_resets_custom_title_between_tests() {
        local test_file=./tests/acceptance/fixtures/test_custom_title.sh
        local output
        output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
        assert_successful_code "$output"
        assert_contains "🔥 handles invalid input with 💣" "$output"
        assert_contains "Default title" "$output"
}
