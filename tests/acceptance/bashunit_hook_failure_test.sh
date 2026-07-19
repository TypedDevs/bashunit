#!/usr/bin/env bash
set -euo pipefail

# Regression guards for #836. A failing set_up_before_script used to produce
# three different outcomes depending on the shape of the hook's last statement
# and the bash version: visible failure (ERR-trap path), silently ignored
# (&&-guard on bash 3.2, real hook status was discarded), or silent failures
# with an off-by-one count (bash >= 4, where the ERR trap fired a second time
# in execute_file_hook's own scope and returned before the failure was
# recorded). One defined behavior now: every test in the file is marked failed
# with an attributed message, counts stay consistent, and the suite continues.

FIXTURES="tests/acceptance/fixtures/hook_failure"

function test_hook_failure_is_attributed_and_suite_continues() {
  local output
  local exit_code=0
  # --detailed: a parent running --simple still exports it (#837), and simple
  # mode would drop the attributed progress lines this test greps for.
  output=$(./bashunit --no-parallel --detailed --skip-env-file \
    "$FIXTURES/plain_hook.sh" "$FIXTURES/guard_hook.sh" "$FIXTURES/later.sh" 2>&1) || exit_code=$?

  assert_general_error "" "" "$exit_code"
  # One attributed error line per failing file (the message repeats in the
  # deferred failure blocks, so count the normalized progress lines).
  assert_equals "2" "$(printf '%s\n' "$output" | grep -c "Set up before script")"
  assert_contains "Later file still runs" "$output"
  assert_contains "1 passed" "$output"
  assert_contains "4 failed" "$output"
  assert_contains "5 total" "$output"
}

function test_hook_failure_counts_match_in_parallel() {
  local output
  local exit_code=0
  output=$(./bashunit --parallel --detailed --skip-env-file \
    "$FIXTURES/plain_hook.sh" "$FIXTURES/guard_hook.sh" "$FIXTURES/later.sh" 2>&1) || exit_code=$?

  assert_general_error "" "" "$exit_code"
  assert_contains "1 passed" "$output"
  assert_contains "4 failed" "$output"
  assert_contains "5 total" "$output"
}
