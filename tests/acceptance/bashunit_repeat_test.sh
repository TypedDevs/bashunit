#!/usr/bin/env bash

# --repeat hammers each selected test n times to flush out flakiness before it
# reaches CI. The fixture tallies its body executions, so "did it really run n
# times" is asserted directly rather than inferred from the summary.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_repeat.sh"
}

function set_up() {
  COUNTER_FILE="$(mktemp)"
  export BASHUNIT_REPEAT_FIXTURE_COUNTER="$COUNTER_FILE"
  printf '0' >"$COUNTER_FILE"
}

function tear_down() {
  rm -f "$COUNTER_FILE"
  unset BASHUNIT_REPEAT_FIXTURE_COUNTER BASHUNIT_REPEAT_FIXTURE_FAIL_ON
}

function test_repeat_runs_the_body_once_per_iteration() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 3 --filter test_repeat_counts "$FIXTURE")"

  assert_same "3" "$(cat "$COUNTER_FILE")"
  assert_contains "Tests: 1 passed, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_repeat_does_not_multiply_the_assertion_count() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 3 --filter test_repeat_counts "$FIXTURE")"

  assert_contains "Assertions: 1 passed, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_repeat_reports_the_failing_iteration() {
  export BASHUNIT_REPEAT_FIXTURE_FAIL_ON=2
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 3 --filter test_repeat_fails "$FIXTURE")" || true

  assert_contains "Tests: 1 failed, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
  assert_contains "iteration 2 of 3" "$output"
}

function test_repeat_stops_the_iterations_at_the_first_failure() {
  export BASHUNIT_REPEAT_FIXTURE_FAIL_ON=2
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 5 --filter test_repeat_fails "$FIXTURE" >/dev/null 2>&1 || true

  assert_same "2" "$(cat "$COUNTER_FILE")"
}

function test_repeat_one_matches_no_flag_at_all() {
  local with_flag without_flag
  without_flag="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --filter test_repeat_counts "$FIXTURE")"
  printf '0' >"$COUNTER_FILE"
  with_flag="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 1 --filter test_repeat_counts "$FIXTURE")"

  assert_same "$without_flag" "$with_flag"
}

# Repeat is the outer loop and retry the inner one: run 1 fails, the retry
# recovers it inside iteration 1, then iteration 2 runs the body once more.
function test_repeat_wraps_retry_rather_than_the_other_way_round() {
  export BASHUNIT_REPEAT_FIXTURE_FAIL_ON=1
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 2 --retry 1 --filter test_repeat_fails "$FIXTURE")"

  assert_contains "Tests: 1 passed" "$(printf '%s' "$output" | tr -s ' ')"
  assert_same "3" "$(cat "$COUNTER_FILE")"
}

function test_repeat_works_in_parallel() {
  local output
  output="$(./bashunit --parallel --no-color --env "$TEST_ENV_FILE" \
    --repeat 3 --filter test_repeat_counts "$FIXTURE")"

  assert_same "3" "$(cat "$COUNTER_FILE")"
  assert_contains "Tests: 1 passed, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_repeat_rejects_zero() {
  local ec=0
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --repeat 0 "$FIXTURE" 2>&1)" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_REPEAT" "$output"
}

function test_repeat_rejects_a_non_numeric_value() {
  local ec=0
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --repeat abc "$FIXTURE" 2>&1)" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_REPEAT" "$output"
}

function test_repeat_rejects_a_negative_value() {
  local ec=0
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --repeat -1 "$FIXTURE" 2>&1)" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_REPEAT" "$output"
}
