#!/usr/bin/env bash

# Nothing stopped a test from reaching a real command: a typo in a mock name
# means the test hits the network and passes, slowly and differently in CI.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_sandbox.sh"
}

function set_up() {
  # A real executable named like the thing a test should never reach for real.
  PROBE_DIR="$(bashunit::temp_dir)/probe_bin"
  mkdir -p "$PROBE_DIR"
  printf '#!/usr/bin/env bash\necho "the real command ran"\n' >"$PROBE_DIR/bashunit_sandbox_probe"
  chmod +x "$PROBE_DIR/bashunit_sandbox_probe"
  PROBE_LOG="$(bashunit::temp_file)"
  : >"$PROBE_LOG"
  export SANDBOX_PROBE_LOG="$PROBE_LOG"
}

function run_fixture() { # $1 = extra flags, $2 = filter
  # shellcheck disable=SC2086
  PATH="$PROBE_DIR:$PATH" NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" $1 \
    --filter "$2" "$FIXTURE" 2>&1 || true
}

function test_an_unmocked_command_fails_the_test_naming_it() {
  local output
  output=$(run_fixture "--sandbox" "test_sandbox_calls_an_unmocked_command")

  assert_contains "bashunit_sandbox_probe" "$output"
  assert_contains "1 failed" "$output"
  assert_empty "$(cat "$PROBE_LOG")"
}

function test_a_mocked_command_passes_under_sandbox() {
  local output
  output=$(run_fixture "--sandbox" "test_sandbox_calls_a_mocked_command")

  assert_contains "1 passed" "$output"
}

function test_an_allowed_command_passes_under_sandbox() {
  local output
  output=$(run_fixture "--sandbox --sandbox-allow bashunit_sandbox_probe" \
    "test_sandbox_calls_an_unmocked_command")

  assert_contains "the real command ran" "$(cat "$PROBE_LOG")"
  assert_contains "1 passed" "$output"
}

function test_builtins_are_unaffected_by_the_sandbox() {
  local output
  output=$(run_fixture "--sandbox" "test_sandbox_uses_builtins_only")

  assert_contains "1 passed" "$output"
}

function test_unmocking_puts_the_command_back_behind_the_sandbox() {
  local output
  output=$(run_fixture "--sandbox" "test_sandbox_after_unmock")

  assert_contains "1 failed" "$output"
  assert_empty "$(cat "$PROBE_LOG")"
}

function test_without_the_flag_the_command_runs_for_real() {
  local output
  output=$(run_fixture "" "test_sandbox_calls_an_unmocked_command")

  assert_contains "the real command ran" "$(cat "$PROBE_LOG")"
  assert_contains "1 passed" "$output"
}

function test_the_sandbox_holds_under_parallel() {
  local output
  output=$(PATH="$PROBE_DIR:$PATH" NO_COLOR=1 ./bashunit --parallel --env "$TEST_ENV_FILE" \
    --sandbox --filter "test_sandbox_calls_an_unmocked_command" "$FIXTURE" 2>&1 || true)

  assert_contains "1 failed" "$output"
  assert_empty "$(cat "$PROBE_LOG")"
}

# The framework itself must keep working: its own suite is full of tests that
# use assertions, temp files, snapshots and hooks.
function test_the_framework_is_not_sandboxed_against_itself() {
  local output
  output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" --sandbox \
    tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1 || true)

  assert_contains "4 passed" "$output"
  assert_not_contains "failed" "$output"
}

function test_an_invalid_sandbox_allow_value_is_rejected() {
  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" --sandbox \
    --sandbox-allow "curl;rm -rf" "$FIXTURE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "invalid --sandbox-allow value" "$output"
}
