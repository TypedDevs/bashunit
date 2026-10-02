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

# The watchdog gave the body a flat 0.3s between its SIGTERM and its SIGKILL,
# which is a scheduling hiccup, not a grace: on a loaded machine the body had
# not even reached tear_down yet, and the #1324 test above failed about one
# parallel full-suite run in three. A tear_down slower than that flat window is
# the deterministic form of the same miss.
function test_bashunit_waits_for_a_slow_tear_down_of_a_timed_out_test() {
  local dir fixture marker
  dir="$(bashunit::temp_dir timeout_slow_teardown)"
  fixture="$dir/hanging_test.sh"
  marker="$dir/marker"
  {
    printf 'function tear_down() { sleep 1; : >"$TIMEOUT_MARKER.teardown"; }\n'
    printf 'function test_hangs() { sleep 30; assert_true true; }\n'
  } >"$fixture"

  local output
  output="$(TIMEOUT_MARKER="$marker" ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --test-timeout 1 "$fixture")" || true

  assert_contains "Test timed out after 1s" "$output"
  assert_file_exists "$marker.teardown"
}

function _assert_timeout_teardown_survives_late_term() {
  local dir fixture events marker
  dir="$(bashunit::temp_dir timeout_late_term)"
  fixture="$dir/hanging_test.sh"
  events="$dir/events"
  marker="$dir/marker"
  cat >"$fixture" <<'TEST'
function kill() {
  if [ "$1" = -TERM ]; then
    case "${2:-}" in
    -*)
      if [ ! -f "$TIMEOUT_EVENTS.delivered" ]; then
        local child_pid
        IFS= read -r child_pid <"$TIMEOUT_EVENTS.child"
        builtin kill -TERM "$child_pid"
        local ticks=0
        while [ ! -f "$TIMEOUT_EVENTS.started" ] && [ "$ticks" -lt 100 ]; do
          sleep 0.01
          ticks=$((ticks + 1))
        done
        : >"$TIMEOUT_EVENTS.delivered"
      fi
      ;;
    esac
  fi
  builtin kill "$@"
}
function tear_down() {
  printf 'started\n' >>"$TIMEOUT_EVENTS"
  : >"$TIMEOUT_EVENTS.started"
  sleep 1
  : >"$TIMEOUT_MARKER.teardown"
  printf 'completed\n' >>"$TIMEOUT_EVENTS"
}
function test_late_term_body_hangs() {
  sleep 30 &
  local child_pid=$!
  printf '%s\n' "$child_pid" >"$TIMEOUT_EVENTS.child"
  wait "$child_pid"
}
TEST

  local output exit_code=0
  output="$(TIMEOUT_EVENTS="$events" TIMEOUT_MARKER="$marker" ./bashunit "$@" \
    --env "$TEST_ENV_FILE" --test-timeout 1 "$fixture")" || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "Test timed out after 1s" "$output"
  assert_file_exists "$events.delivered"
  assert_same "started
completed" "$(cat "$events")"
  assert_file_exists "$marker.teardown"
}

function test_sequential_timeout_keeps_a_late_term_from_interrupting_teardown() {
  _assert_timeout_teardown_survives_late_term --no-parallel
}

function test_parallel_timeout_keeps_a_late_term_from_interrupting_teardown() {
  _assert_timeout_teardown_survives_late_term --parallel
}

function test_strict_sequential_timeout_preserves_teardown_after_a_late_term() {
  _assert_timeout_teardown_survives_late_term --no-parallel --strict
}

function test_strict_parallel_timeout_preserves_teardown_after_a_late_term() {
  _assert_timeout_teardown_survives_late_term --parallel --strict
}

function test_timeout_still_stops_a_hanging_teardown_after_the_grace() {
  local dir fixture marker
  dir="$(bashunit::temp_dir timeout_hanging_teardown)"
  fixture="$dir/hanging_test.sh"
  marker="$dir/marker"
  cat >"$fixture" <<'TEST'
function kill() {
  if [ "$1" = -KILL ]; then
    : >"$TIMEOUT_MARKER.killed"
  fi
  builtin kill "$@"
}
function tear_down() {
  : >"$TIMEOUT_MARKER.started"
  sleep 10
  : >"$TIMEOUT_MARKER.completed"
}
function test_hanging_teardown_body_hangs() { sleep 30; }
TEST

  local output exit_code=0
  output="$(TIMEOUT_MARKER="$marker" ./bashunit --no-parallel \
    --env "$TEST_ENV_FILE" --test-timeout 1 "$fixture")" || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "Test timed out after 1s" "$output"
  assert_file_exists "$marker.started"
  assert_file_exists "$marker.killed"
  assert_file_not_exists "$marker.completed"
}

function _timeout_body_is_running() {
  local body_pid="$1"
  kill -0 "$body_pid" 2>/dev/null || return 1
  local state
  if [ -r "/proc/$body_pid/stat" ]; then
    IFS= read -r state 2>/dev/null <"/proc/$body_pid/stat" || return 1
    state=${state##*) }
    state=${state%% *}
  else
    state=$(ps -p "$body_pid" -o stat= 2>/dev/null) || return 1
  fi
  # A cancelled runner can leave an exited body awaiting reaping by its new parent.
  case "$state" in
  *Z* | "") return 1 ;;
  esac
  return 0
}

function _assert_cancellation_stops_timeout_teardown() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "Unix process-group signals"
    return
  fi

  local timeout="$1"
  local hangs="$2"
  local dir fixture marker
  dir="$(bashunit::temp_dir timeout_cancel_teardown)"
  fixture="$dir/hanging_test.sh"
  marker="$dir/marker"
  # Parallel tests can inherit ignored SIGINT, so invoke its cleanup handler through USR1.
  cat >"$fixture" <<'TEST'
trap 'bashunit::main::cleanup' USR1
function pkill() {
  local body_pid
  IFS= read -r body_pid <"$TIMEOUT_MARKER.body"
  builtin kill -TERM -"$body_pid" 2>/dev/null || true
  command pkill "$@"
}
function tear_down() {
  sh -c 'printf "%s\n" "$PPID"' >"$TIMEOUT_MARKER.body"
  : >"$TIMEOUT_MARKER.started"
  sleep 30
  : >"$TIMEOUT_MARKER.completed"
}
function test_cancellation_body() {
  if [ "$TIMEOUT_BODY_HANGS" = true ]; then
    sleep 30
  else
    assert_true true
  fi
}
TEST

  local output start
  start=$(date +%s)
  output=$(
    set -m
    TIMEOUT_MARKER="$marker" TIMEOUT_BODY_HANGS="$hangs" ./bashunit --no-parallel \
      --env "$TEST_ENV_FILE" --test-timeout "$timeout" "$fixture" &
    run_pid=$!
    set +m
    ticks=0
    while [ ! -f "$marker.started" ] && [ "$ticks" -lt 100 ]; do
      sleep 0.05
      ticks=$((ticks + 1))
    done
    kill -USR1 "$run_pid" 2>/dev/null || true
    wait "$run_pid" 2>/dev/null || true
    if [ -f "$marker.body" ]; then
      IFS= read -r body_pid <"$marker.body"
      ticks=0
      while _timeout_body_is_running "$body_pid" && [ "$ticks" -lt 60 ]; do
        sleep 0.05
        ticks=$((ticks + 1))
      done
      if _timeout_body_is_running "$body_pid"; then
        if [ -r "/proc/$body_pid/stat" ]; then
          cat "/proc/$body_pid/stat" 2>/dev/null || true
        else
          ps -p "$body_pid" -o pid=,ppid=,pgid=,stat= 2>/dev/null || true
        fi
        : >"$marker.forced"
        kill -KILL -"$body_pid" 2>/dev/null || true
      fi
    fi
  ) || true

  if [ ! -f "$marker.started" ] || [ -f "$marker.forced" ]; then
    printf '%s\n' "$output"
  fi
  assert_file_exists "$marker.started"
  assert_contains "Caught Ctrl-C, killing all child processes" "$output"
  assert_file_not_exists "$marker.forced"
  if [ "$hangs" = true ]; then
    assert_file_not_exists "$marker.completed"
  fi
  assert_less_than 20 "$(($(date +%s) - start))"
}

function test_cancellation_before_timeout_does_not_leave_cleanup_running() {
  _assert_cancellation_stops_timeout_teardown 60 false
}

function test_cancellation_keeps_the_timeout_cleanup_grace_bounded() {
  _assert_cancellation_stops_timeout_teardown 1 true
}
