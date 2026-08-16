#!/usr/bin/env bash

# The run using this fixture is SIGKILLed while the test below is still in
# flight, so the timeout watchdog is guaranteed to outlive its parent. The
# sleep only has to be long enough to survive the kill.
function test_sleeps_past_the_kill() {
  sleep 5
  assert_same "never" "reached"
}
