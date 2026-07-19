#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_retry.sh"
}

function set_up() {
  COUNTER_FILE="$(mktemp)"
  export BASHUNIT_RETRY_FIXTURE_COUNTER="$COUNTER_FILE"
  printf '0' >"$COUNTER_FILE"
}

function tear_down() {
  rm -f "$COUNTER_FILE"
  unset BASHUNIT_RETRY_FIXTURE_COUNTER BASHUNIT_RETRY_FIXTURE_PASS_ON
}

function test_bashunit_retry_recovers_a_flaky_test() {
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=2
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky "$FIXTURE")"

  assert_contains "1 passed" "$output"
  assert_same "2" "$(cat "$COUNTER_FILE")"
}

function test_bashunit_retry_annotates_a_test_that_only_passed_on_retry() {
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=2
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky "$FIXTURE")"

  assert_contains "retry" "$output"
}

function test_bashunit_without_retry_a_flaky_test_fails() {
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=2
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --retry 0 --filter test_a_flaky "$FIXTURE")" || true

  assert_contains "1 failed" "$output"
  assert_same "1" "$(cat "$COUNTER_FILE")"
}

function test_bashunit_retry_gives_up_after_exhausting_attempts() {
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=99
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --retry 2 --filter test_a_flaky "$FIXTURE")" || true

  # Counted once, not once per attempt.
  assert_contains "1 failed" "$output"
  # 1 initial run + 2 retries.
  assert_same "3" "$(cat "$COUNTER_FILE")"
}

function test_bashunit_retry_recovers_a_flaky_test_in_parallel() {
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=2
  local output
  output="$(./bashunit --parallel --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky "$FIXTURE")"

  assert_contains "1 passed" "$output"
}

function test_bashunit_retry_defers_stop_on_failure_until_attempts_exhausted() {
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=2
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --stop-on-failure --retry 1 "$FIXTURE")"

  # The flaky test recovers on retry, so stop-on-failure never fires and the
  # later test still runs.
  assert_contains "2 passed" "$output"
}
