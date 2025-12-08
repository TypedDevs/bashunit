#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_preserve_env_skips_dotenv_loading() {
  # The project .env sets BASHUNIT_BOOTSTRAP="" which would override this
  local output
  output=$(BASHUNIT_BOOTSTRAP="tests/acceptance/fixtures/bootstrap_with_args.sh" \
    BASHUNIT_BOOTSTRAP_ARGS="hello world" \
    BASHUNIT_PRESERVE_ENV=true \
    ./bashunit --no-parallel --simple \
    tests/acceptance/fixtures/test_bootstrap_args.sh 2>&1) || true

  assert_contains "All tests passed" "$output"
}

function test_preserve_env_via_flag() {
  local output
  output=$(BASHUNIT_BOOTSTRAP="tests/acceptance/fixtures/bootstrap_with_args.sh" \
    BASHUNIT_BOOTSTRAP_ARGS="hello world" \
    ./bashunit --no-parallel --simple --preserve-env \
    tests/acceptance/fixtures/test_bootstrap_args.sh 2>&1) || true

  assert_contains "All tests passed" "$output"
}

function test_without_preserve_env_loads_dotenv() {
  # Without --preserve-env, the .env should be loaded
  # This test verifies normal behavior still works
  local output
  output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" \
    tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1) || true

  assert_contains "All tests passed" "$output"
}
