#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
        sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_bashunit_risky_test_shows_warning() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

        local actual_raw
        actual_raw="$(BASHUNIT_STRICT_MODE=false ./bashunit \
                --no-parallel --detailed --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"

        local actual
        actual="$(printf "%s" "$actual_raw" | strip_ansi)"

        assert_contains "Risky" "$actual"
        assert_contains "1 risky" "$actual"
}

function test_bashunit_risky_test_does_not_fail() {
        local test_file=./tests/acceptance/fixtures/test_bashunit_risky_no_assertions.sh

        local actual_raw
        actual_raw="$(BASHUNIT_STRICT_MODE=false ./bashunit \
                --no-parallel --simple --skip-env-file --env "$TEST_ENV_FILE" "$test_file")"

        local actual
        actual="$(printf "%s" "$actual_raw" | strip_ansi)"

        assert_contains "risky" "$actual"
        assert_not_contains "failed" "$actual"
}
