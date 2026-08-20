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
  local workdir
  workdir=$(bashunit::temp_dir killed_run)
  local probe="$workdir/body-started"
  # The body announces itself rather than the caller guessing a delay: the
  # watchdog exists only while a test body does, and on a slow runner a fixed
  # sleep killed the run before it had started one -- or printed anything.
  cat >"$workdir/killed_test.sh" <<TEST
function test_body_in_flight_when_the_run_is_killed() {
  : >"$probe"
  sleep 3
  assert_same "never" "reached"
}
TEST

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
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 15 "$workdir" &
    run_pid=$!
    waited=0
    while [ ! -f "$probe" ] && [ "$waited" -lt 300 ]; do
      sleep 0.1
      waited=$((waited + 1))
    done
    kill -9 "$run_pid" 2>/dev/null
    wait "$run_pid" 2>/dev/null
  ) || true
  end=$(date +%s)

  # The floor is the body's own sleep, which legitimately keeps the run's
  # stdout: a still-running test body is indistinguishable from one about to
  # print. The ceiling only has to sit below the timeout budget, which is what a
  # leaked descriptor makes the caller wait out in full.
  assert_contains "Running" "$output"
  assert_less_than 10 "$((end - start))"
}

# A timed-out test was killed without running tear_down, so whatever set_up had
# acquired for it was leaked (#1324). The file-scoped hook already survived,
# because the runner loop carries on to the next file.
#
# A 30s sleep against a 1s budget, so the test is still running when the budget
# expires however loaded the runner is. #1093 is the other direction of the same
# care: never assert on a fast test with a budget it could cross.
function test_bashunit_runs_tear_down_for_a_timed_out_test() {
  local dir fixture marker
  dir="$(bashunit::temp_dir timeout_teardown)"
  fixture="$dir/hanging_test.sh"
  marker="$dir/marker"
  {
    printf 'function set_up() { : >"$TIMEOUT_MARKER.setup"; }\n'
    printf 'function tear_down() { : >"$TIMEOUT_MARKER.teardown"; }\n'
    printf 'function test_hangs() { sleep 30; assert_true true; }\n'
  } >"$fixture"

  local output
  output="$(TIMEOUT_MARKER="$marker" ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --test-timeout 1 "$fixture")" || true

  assert_contains "Test timed out after 1s" "$output"
  assert_file_exists "$marker.setup"
  assert_file_exists "$marker.teardown"
}
