#!/usr/bin/env bash
set -euo pipefail

# `docs/examples.md` sends readers to `example/` first, and `example/README.md`
# tells them to run `./bashunit example` from the project root. That is a new
# user's first contact with the framework, and nothing ran it: `make test`
# collects from `tests/` only, no workflow mentions the folder, and no test
# referenced it. It could rot -- a renamed assertion, a moved source file --
# while CI stayed green (#1219).
#
# Assert on the outcome, not on a test count, so adding an example does not
# fail this; what must never happen is the demo failing.

function set_up_before_script() {
  ROOT_DIR="$(pwd)"
}

function _run_example() { # $@ = extra flags
  (cd "$ROOT_DIR" && ./bashunit "$@" example 2>&1) || echo "EXIT_FAILURE"
}

# The command the README documents, verbatim -- no trailing slash.
function test_the_documented_example_command_succeeds() {
  local output
  output="$(_run_example --no-parallel | strip_ansi)"

  assert_not_contains "EXIT_FAILURE" "$output"
  assert_contains "All tests passed" "$output"
}

# The demo is also what a user copies into their own project, where the run is
# as likely to be parallel.
function test_the_example_folder_passes_in_parallel_too() {
  local output
  output="$(_run_example --parallel | strip_ansi)"

  assert_not_contains "EXIT_FAILURE" "$output"
  assert_contains "All tests passed" "$output"
}

# A guard that runs zero tests would pass forever. The folder holding no tests
# at all is itself the failure this is here to catch.
function test_the_example_folder_actually_holds_tests() {
  local output
  output="$(_run_example --no-parallel --list)"

  assert_not_contains "EXIT_FAILURE" "$output"
  assert_matches "[1-9][0-9]* tests" "$output"
}
