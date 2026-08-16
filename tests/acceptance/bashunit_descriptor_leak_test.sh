#!/usr/bin/env bash
set -euo pipefail

# Bash 3.x reaps the descriptors process substitution allocates only when it
# returns to the top level or after forking an external command. bashunit scans
# every test file from inside a function the run never leaves, so a `< <(…)`
# there leaks one descriptor per file. Nothing noticed while a per-file `rm`
# fork happened to follow it and collect them; removing that fork for #1271
# turned it loose.
#
# The failure is the worst kind for a test runner: at the limit the run stops
# executing tests and says "risky" rather than failing. 120 files under a
# 120-descriptor limit ran 2 assertions instead of 120, and still exited 0.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FILE_COUNT=120
  FD_LIMIT=120
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir descriptor_leak)"
  local i=1
  while [ "$i" -le "$FILE_COUNT" ]; do
    printf 'function test_d%s() { assert_same 1 1; }\n' "$i" >"$WORKDIR/d${i}_test.sh"
    i=$((i + 1))
  done
}

# The descriptor limit is the assertion. Counting open descriptors would need a
# per-platform probe; running out of them is the thing users actually hit, and
# one file must not cost one.
function test_a_sequential_run_does_not_leak_a_descriptor_per_file() {
  local output
  output=$(
    ulimit -n "$FD_LIMIT" 2>/dev/null || true
    "$BASHUNIT_BIN" --no-parallel --skip-env-file "$WORKDIR" 2>&1
  ) || true

  assert_contains "$FILE_COUNT passed" "$output"
  assert_not_contains "risky" "$output"
}
