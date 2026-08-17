#!/usr/bin/env bash
set -euo pipefail

# A test file's path is data, never code. The per-test EXIT trap used to be
# built by interpolating the path into the trap string, and a trap body is
# re-evaluated by the shell when it fires -- so a path holding a command
# substitution ran it. Double quotes around the interpolation stopped word
# splitting but not substitution.
#
# The exposure is a CI job checking out a branch and running `bashunit tests/`:
# whoever can add a file to the tree chooses the command.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir hostile_path)"
  mkdir -p "$WORKDIR/tests"
}

# `touch INJECTED` is relative, so the marker would land in the run's cwd.
function test_a_backtick_in_a_test_path_is_not_executed() {
  local nasty="$WORKDIR/tests/x\`touch INJECTED\`y_test.sh"
  printf 'function test_probe() { assert_same "1" "1"; }\n' >"$nasty"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file tests/) >/dev/null 2>&1 || true

  assert_file_not_exists "$WORKDIR/INJECTED"
}

function test_a_dollar_paren_in_a_test_path_is_not_executed() {
  local nasty="$WORKDIR/tests/x\$(touch INJECTED2)y_test.sh"
  printf 'function test_probe2() { assert_same "1" "1"; }\n' >"$nasty"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file tests/) >/dev/null 2>&1 || true

  assert_file_not_exists "$WORKDIR/INJECTED2"
}

# The same path under --parallel, where the trap is set inside a worker.
function test_a_backtick_in_a_test_path_is_not_executed_in_parallel() {
  local nasty="$WORKDIR/tests/x\`touch INJECTED3\`y_test.sh"
  printf 'function test_probe3() { assert_same "1" "1"; }\n' >"$nasty"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --parallel --skip-env-file tests/) >/dev/null 2>&1 || true

  assert_file_not_exists "$WORKDIR/INJECTED3"
}

# And the test still actually runs: the assertion must be counted, not lost to a
# mangled path. The substitution used to swallow part of the name, so the file
# that got sourced was not the one on disk and the test reported risky.
function test_a_test_in_a_hostile_path_still_runs_its_assertions() {
  local nasty="$WORKDIR/tests/x\`echo hi\`y_test.sh"
  printf 'function test_counts() { assert_same "a" "b"; }\n' >"$nasty"

  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file tests/ 2>&1) || true

  assert_contains "1 failed" "$output"
  assert_not_contains "risky" "$output"
}
