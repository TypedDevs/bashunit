#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_timeout.sh"
}

function test_bashunit_terminates_a_hanging_test_with_timeout() {
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 1 "$FIXTURE")" || true

  assert_contains "Test timed out after 1s" "$output"
}

function test_bashunit_keeps_running_tests_after_a_timed_out_one() {
  # The only case here that asserts on the FAST test, so the only one whose
  # budget has to cover how long that test takes to run rather than how long
  # the blocked one sleeps. One second did not: the watchdog marks a test that
  # is still running when the budget expires, and on a CI runner already busy
  # with the parallel suite even an immediate assertion crossed it, so the run
  # reported `2 failed` and the job went red (#1093). Five seconds against a
  # thirty-second sleep still proves both halves.
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 5 "$FIXTURE")" || true

  # The fast test still ran and passed and the run reached its summary instead
  # of hanging forever on the blocked test.
  assert_contains "1 passed" "$output"
  assert_contains "1 failed" "$output"
}

function test_bashunit_returns_error_when_a_test_times_out() {
  assert_general_error \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 1 "$FIXTURE")"
}

function test_bashunit_does_not_time_out_a_fast_test() {
  local fast_only=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_successful_code \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 5 "$fast_only")"
}

# A caller capturing a run's output waits for EOF on the pipe, which arrives
# only once every process holding the write end has gone. The watchdog is
# detached from stdout, so killing the run must end the capture at once -- and
# it did not, because a descriptor the runner had left open leaked into the
# watchdog's `sleep`, pinning the caller for the whole timeout budget (#1137).
function test_a_killed_run_releases_its_captured_output_at_once() {
  local killed_fixture=./tests/acceptance/fixtures/test_bashunit_timeout_killed.sh
  local start=0
  local end=0
  local output=""

  start=$(date +%s)
  output=$(
    # Stand-ins for the two dups of stdout the runner hands a test body, which a
    # nested run inherits for real. Pointing them at this capture is what makes
    # a leak observable: what the killed run must not leave behind is a process
    # holding this pipe, on FD 1 or on any descriptor it was handed.
    exec 3>&1 5>&1
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 20 "$killed_fixture" &
    run_pid=$!
    sleep 2
    kill -9 "$run_pid" 2>/dev/null
    wait "$run_pid" 2>/dev/null
  ) || true
  end=$(date +%s)

  # The floor is the fixture's own sleep, which legitimately keeps the run's
  # stdout: a still-running test body is indistinguishable from one about to
  # print. The ceiling only has to sit below the timeout budget, which is what a
  # leaked descriptor makes the caller wait out in full.
  assert_contains "Running" "$output"
  assert_less_than 12 "$((end - start))"
}
