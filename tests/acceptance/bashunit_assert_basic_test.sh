#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

# Test basic assert subcommand functionality
function test_bashunit_assert_subcommand_equals() {
  ./bashunit assert equals "foo" "foo"
  assert_successful_code
}

function test_bashunit_assert_subcommand_same() {
  ./bashunit assert same "1" "1"
  assert_successful_code
}

function test_bashunit_assert_subcommand_contains() {
  ./bashunit assert contains "world" "hello world"
  assert_successful_code
}

function test_bashunit_assert_subcommand_without_prefix() {
  ./bashunit assert equals "bar" "bar"
  assert_successful_code
}

# Test help functionality
function test_bashunit_assert_subcommand_help_short() {
  local output
  output=$(./bashunit assert -h 2>&1)

  assert_contains "Usage: bashunit assert" "$output"
  assert_contains "Run standalone assertion" "$output"
  assert_successful_code "$(./bashunit assert -h)"
}

function test_bashunit_assert_subcommand_help_long() {
  local output
  output=$(./bashunit assert --help 2>&1)

  assert_contains "Usage: bashunit assert" "$output"
  assert_contains "Single assertion:" "$output"
  assert_successful_code "$(./bashunit assert --help)"
}

# Test assert subcommand is in main help
function test_bashunit_main_help_includes_assert() {
  local output
  output=$(./bashunit --help 2>&1)

  assert_contains "assert <fn> <args>" "$output"
}

function test_multi_assert_help_shows_multi_syntax() {
  local output
  output=$(./bashunit assert --help 2>&1)
  assert_contains "Multiple assertions on command output" "$output"
}

# assert_exec runs the command with `eval "$cmd" >out 2>err` and reads $? on the
# next line. Under --strict the runner enables set -e, so a command that exits
# non-zero aborts the test function there and the assertion never runs: the one
# assertion whose job is checking an exit code could not check a failing one
# (#1207). Success cases were unaffected, which is why it went unnoticed.
function test_assert_exec_can_assert_a_nonzero_exit_under_strict() {
  local dir
  dir="$(bashunit::temp_dir)"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$dir/fails.sh"
  chmod +x "$dir/fails.sh"
  printf 'function test_x() { assert_exec "%s/fails.sh" --exit 1; }\n' "$dir" >"$dir/e_test.sh"

  local output
  output=$(./bashunit --no-parallel --strict "$dir/e_test.sh" 2>&1) || true
  output=$(printf '%s' "$output" | strip_ansi)

  assert_contains "1 passed" "$output"
  assert_not_contains "✗" "$output"
}

function test_assert_exec_still_asserts_a_zero_exit_under_strict() {
  local dir
  dir="$(bashunit::temp_dir)"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/ok.sh"
  chmod +x "$dir/ok.sh"
  printf 'function test_x() { assert_exec "%s/ok.sh" --exit 0; }\n' "$dir" >"$dir/o_test.sh"

  local output
  output=$(./bashunit --no-parallel --strict "$dir/o_test.sh" 2>&1) || true

  assert_contains "1 passed" "$(printf '%s' "$output" | strip_ansi)"
}
