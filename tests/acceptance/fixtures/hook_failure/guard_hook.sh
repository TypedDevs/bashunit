#!/usr/bin/env bash
# shellcheck disable=SC2034  # the guard variable is the point of the fixture
set -euo pipefail

# The hook's last statement is a failing `cmd && assignment` guard, so the hook
# returns 1 without triggering the ERR trap (the failure is inside a && list).
function set_up_before_script() {
  GUARD_FLAG=false
  command -v definitely_missing_tool_bashunit >/dev/null 2>&1 && GUARD_FLAG=true
}

function test_guard_one() { assert_true true; }
function test_guard_two() { assert_true true; }
