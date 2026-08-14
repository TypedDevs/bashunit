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

# The boundary the docs draw. A child process inherits the narrowed PATH, so it
# cannot resolve the command at all -- that is what makes `sh -c 'curl …'`
# useless as an escape on Linux and macOS. It holds because the sandbox replaces
# PATH rather than prepending to it.
function test_sandbox_child_process_cannot_resolve_the_command() {
  sh -c 'command -v bashunit_sandbox_probe' >"${SANDBOX_PROBE_LOG:?log required}" 2>/dev/null
  assert_same "ok" "ok"
}

# The documented limitation, pinned so it stays a known boundary rather than a
# surprise: an absolute path skips PATH entirely and is not blocked.
function test_sandbox_absolute_path_is_not_blocked() {
  "${SANDBOX_PROBE_ABS:?abs path required}" >"${SANDBOX_PROBE_LOG:?log required}" 2>/dev/null
  assert_same "ok" "ok"
}
