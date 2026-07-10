#!/usr/bin/env bash

# Deterministic stand-in for a flaky test: a persistent counter file survives
# across retry attempts (each attempt re-runs the body), so the test fails until
# the attempt count reaches BASHUNIT_RETRY_FIXTURE_PASS_ON.
function test_a_flaky_until_nth_attempt() {
  local counter_file="${BASHUNIT_RETRY_FIXTURE_COUNTER:?counter file required}"
  local pass_on="${BASHUNIT_RETRY_FIXTURE_PASS_ON:-2}"

  local attempts
  attempts=$(cat "$counter_file" 2>/dev/null || echo 0)
  attempts=$((attempts + 1))
  printf '%s' "$attempts" >"$counter_file"

  if [ "$attempts" -ge "$pass_on" ]; then
    assert_same "ok" "ok"
  else
    assert_same "pass-on-attempt-$pass_on" "failed-on-attempt-$attempts"
  fi
}

function test_b_always_passes() {
  assert_same "ran" "ran"
}
