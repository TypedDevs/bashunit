#!/usr/bin/env bash

# Both at once: the assertion fails, then the shell cannot find the command.
# bashunit renders the failure inside the capture subshell, so its own text
# precedes the diagnostic in the captured output.
function test_fails_an_assertion_and_then_hits_a_shell_error() {
  assert_same "a" "b"
  no_such_command_from_a_fixture
}
