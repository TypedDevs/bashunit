#!/usr/bin/env bash

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_skip_env_file_skips_dotenv_loading() {
        # The project .env sets BASHUNIT_BOOTSTRAP="" which would override this
        local output
        output=$(BASHUNIT_BOOTSTRAP="tests/acceptance/fixtures/bootstrap_with_args.sh" \
                BASHUNIT_BOOTSTRAP_ARGS="hello world" \
                BASHUNIT_SKIP_ENV_FILE=true \
                ./bashunit --no-parallel --simple \
                tests/acceptance/fixtures/test_bootstrap_args.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}

function test_skip_env_file_via_flag() {
        local output
        output=$(BASHUNIT_BOOTSTRAP="tests/acceptance/fixtures/bootstrap_with_args.sh" \
                BASHUNIT_BOOTSTRAP_ARGS="hello world" \
                ./bashunit --no-parallel --simple --skip-env-file \
                tests/acceptance/fixtures/test_bootstrap_args.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}

function test_without_skip_env_file_loads_dotenv() {
        # Without --skip-env-file, the .env should be loaded
        # This test verifies normal behavior still works
        local output
        output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}
