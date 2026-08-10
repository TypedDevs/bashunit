#!/usr/bin/env bash

# Body executions are tallied in a file that survives the iterations, so a test
# can assert how many times --repeat actually ran the body.
function _repeat_fixture_tick() {
  local counter_file="${BASHUNIT_REPEAT_FIXTURE_COUNTER:?counter file required}"
  local runs
  runs=$(cat "$counter_file" 2>/dev/null || echo 0)
  runs=$((runs + 1))
  printf '%s' "$runs" >"$counter_file"
  echo "$runs"
}

function test_repeat_counts_its_runs() {
  _repeat_fixture_tick >/dev/null
  assert_same "ok" "ok"
}

# Fails only on the execution named by BASHUNIT_REPEAT_FIXTURE_FAIL_ON, so a
# test can place the failure on a chosen iteration.
function test_repeat_fails_on_a_chosen_run() {
  local runs
  runs=$(_repeat_fixture_tick)

  if [ "$runs" = "${BASHUNIT_REPEAT_FIXTURE_FAIL_ON:-0}" ]; then
    assert_same "expected" "actual-on-run-$runs"
  else
    assert_same "ok" "ok"
  fi
}
