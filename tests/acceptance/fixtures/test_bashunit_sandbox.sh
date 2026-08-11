#!/usr/bin/env bash

# Fixture for --sandbox. `bashunit_sandbox_probe` stands in for curl/git/aws:
# a real executable on PATH that no test should reach unmocked. What it printed
# (if it ran at all) is left in $SANDBOX_PROBE_LOG for the acceptance test.

function test_sandbox_calls_an_unmocked_command() {
  bashunit_sandbox_probe >"${SANDBOX_PROBE_LOG:?log required}" 2>/dev/null
  assert_same "ok" "ok"
}

function test_sandbox_calls_a_mocked_command() {
  bashunit::mock bashunit_sandbox_probe echo "mocked"

  assert_same "mocked" "$(bashunit_sandbox_probe)"
}

function test_sandbox_uses_builtins_only() {
  local value="abc"

  echo "$value" >/dev/null
  printf '%s' "$value" >/dev/null
  if [ -n "$value" ]; then
    assert_same "abc" "$value"
  fi
}

function test_sandbox_after_unmock_the_command_is_blocked_again() {
  bashunit::mock bashunit_sandbox_probe echo "mocked"
  bashunit::unmock bashunit_sandbox_probe

  bashunit_sandbox_probe >"${SANDBOX_PROBE_LOG:?log required}" 2>/dev/null
  assert_same "ok" "ok"
}
