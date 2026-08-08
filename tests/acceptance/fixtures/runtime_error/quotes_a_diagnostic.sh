#!/usr/bin/env bash

# A test whose subject is error handling: its output legitimately contains the
# text of a shell diagnostic, as data. The test fails on its assertion, but
# nothing went wrong at runtime -- it must not also be reported as an Error.
function test_quotes_a_shell_diagnostic_as_data() {
  local captured="bash: some_tool: command not found"

  assert_same "expected something else" "$captured"
}
