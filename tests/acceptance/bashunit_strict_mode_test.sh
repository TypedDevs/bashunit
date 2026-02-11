#!/usr/bin/env bash

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_permissive_mode_allows_unset_variables() {
        local output
        output=$(BASHUNIT_STRICT_MODE=false ./bashunit --no-parallel --simple --skip-env-file --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/strict_mode_unset_variable.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}

function test_strict_mode_fails_on_unset_variables() {
        local output
        output=$(BASHUNIT_STRICT_MODE=true ./bashunit --no-parallel --simple --skip-env-file --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/strict_mode_unset_variable.sh 2>&1) || true

        assert_contains "failed" "$output"
}

function test_permissive_mode_allows_nonzero_returns() {
        local output
        output=$(BASHUNIT_STRICT_MODE=false ./bashunit --no-parallel --simple --skip-env-file --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/strict_mode_nonzero_return.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}

function test_strict_mode_fails_on_nonzero_returns() {
        local output
        output=$(BASHUNIT_STRICT_MODE=true ./bashunit --no-parallel --simple --skip-env-file --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/strict_mode_nonzero_return.sh 2>&1) || true

        assert_contains "failed" "$output"
}

function test_cli_flag_overrides_env_var() {
        local output
        output=$(BASHUNIT_STRICT_MODE=false ./bashunit \
                --no-parallel --simple --skip-env-file --strict --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/strict_mode_unset_variable.sh 2>&1) || true

        assert_contains "failed" "$output"
}
