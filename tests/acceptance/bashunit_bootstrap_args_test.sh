#!/usr/bin/env bash

function set_up_before_script() {
        TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bootstrap_receives_arguments_via_env_flag() {
        local output
        output=$(./bashunit --no-parallel --simple \
                --env "tests/acceptance/fixtures/bootstrap_with_args.sh hello world" \
                tests/acceptance/fixtures/test_bootstrap_args.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}

function test_bootstrap_without_arguments_still_works() {
        local output
        output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" \
                tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}

function test_bootstrap_args_via_env_variable() {
        local output
        # Use --env flag to set the bootstrap file (avoiding .env override),
        # but use BASHUNIT_BOOTSTRAP_ARGS from environment
        output=$(BASHUNIT_BOOTSTRAP_ARGS="hello world" \
                ./bashunit --no-parallel --simple \
                --env "tests/acceptance/fixtures/bootstrap_with_args.sh" \
                tests/acceptance/fixtures/test_bootstrap_args.sh 2>&1) || true

        assert_contains "All tests passed" "$output"
}
