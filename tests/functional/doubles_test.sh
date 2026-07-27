#!/bin/bash
# shellcheck external-sources=false
# shellcheck disable=SC1091

function test_mock_ps_when_executing_a_script() {
  bashunit::mock ps cat ./tests/functional/fixtures/doubles_ps_output

  assert_match_snapshot "$(source ./tests/functional/fixtures/doubles_script.sh)"
}

function test_mock_ps_when_executing_a_sourced_function() {
  source ./tests/functional/fixtures/doubles_function.sh
  bashunit::mock ps cat ./tests/functional/fixtures/doubles_ps_output

  assert_match_snapshot "$(top_mem)"
}

function test_spy_commands_called_when_executing_a_script() {
  # Skip on Bash 3.0 - shell function exports don't work for external scripts
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]]; then
    bashunit::skip "Spies do not reach external scripts on Bash 3.x"
    return
  fi

  bashunit::spy ps
  bashunit::spy awk
  bashunit::spy head

  ./tests/functional/fixtures/doubles_script.sh

  assert_have_been_called ps
  assert_have_been_called awk
  assert_have_been_called head
}

function test_spy_commands_called_when_executing_a_sourced_function() {
  source ./tests/functional/fixtures/doubles_function.sh
  bashunit::spy ps
  bashunit::spy awk
  bashunit::spy head

  top_mem

  assert_have_been_called ps
  assert_have_been_called awk
  assert_have_been_called head
}

function test_spy_commands_called_once_when_executing_a_script() {
  # Skip on Bash 3.0 - shell function exports don't work for external scripts
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]]; then
    bashunit::skip "Spies do not reach external scripts on Bash 3.x"
    return
  fi
  # Skip when coverage is enabled because coverage uses head internally,
  # which interferes with spying on head
  if bashunit::env::is_coverage_enabled; then
    bashunit::skip "Cannot spy on head when coverage is enabled"
    return
  fi

  bashunit::spy ps
  bashunit::spy awk
  bashunit::spy head

  ./tests/functional/fixtures/doubles_script.sh

  assert_have_been_called_times 1 ps
  assert_have_been_called_times 1 awk
  assert_have_been_called_times 1 head
}

function test_spy_commands_called_once_when_executing_a_sourced_function() {
  # Skip when coverage is enabled because coverage uses head internally,
  # which interferes with spying on head
  if bashunit::env::is_coverage_enabled; then
    bashunit::skip "Cannot spy on head when coverage is enabled"
    return
  fi

  source ./tests/functional/fixtures/doubles_function.sh
  bashunit::spy ps
  bashunit::spy awk
  bashunit::spy head

  top_mem

  assert_have_been_called_times 1 ps
  assert_have_been_called_times 1 awk
  assert_have_been_called_times 1 head
}

function test_mock_mktemp_does_not_break_spy_creation() {
  # shellcheck disable=SC2329
  mock_mktemp() {
    echo "/tmp/mocked_temp_file"
  }

  bashunit::mock mktemp mock_mktemp

  bashunit::spy rm

  rm -f "/tmp/mocked_temp_file"

  assert_have_been_called rm
  assert_have_been_called_times 1 rm
  assert_have_been_called_with rm "-f" "/tmp/mocked_temp_file"
}

function test_spy_call_with_args_matches_exact_argument_boundaries() {
  bashunit::spy spy_boundary_command

  spy_boundary_command "a b"

  assert_empty "$(assert_have_been_called_with_args spy_boundary_command "a b")"
}

function test_spy_call_with_args_detects_wrong_argument_boundaries() {
  bashunit::spy spy_boundary_command

  spy_boundary_command "a b"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Spy call with args detects wrong argument boundaries" \
      "a b" "but got " "a\\ b")" \
    "$(assert_have_been_called_with_args spy_boundary_command "a" "b")"
}

function test_assert_not_called_fails_when_the_command_was_never_spied() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert not called fails when the command was never spied" \
      "never_spied_command" "was never registered as a spy; call it first with" \
      "bashunit::spy never_spied_command")" \
    "$(assert_not_called never_spied_command)"
}

function test_call_assertions_fail_when_the_command_was_never_spied() {
  local label="Call assertions fail when the command was never spied"
  local expected
  expected="$(bashunit::console_results::print_failed_test "$label" \
    "never_spied_command" "was never registered as a spy; call it first with" \
    "bashunit::spy never_spied_command")"

  assert_same "$expected" "$(assert_have_been_called never_spied_command)"
  assert_same "$expected" "$(assert_have_been_called_times 0 never_spied_command)"
  assert_same "$expected" "$(assert_have_been_called_with never_spied_command "x")"
  assert_same "$expected" "$(assert_have_been_called_with_args never_spied_command "x")"
  assert_same "$expected" "$(assert_have_been_called_nth_with 1 never_spied_command "x")"
}

function test_call_assertions_fail_after_the_spy_was_unmocked() {
  bashunit::spy spy_to_be_unmocked
  bashunit::unmock spy_to_be_unmocked

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Call assertions fail after the spy was unmocked" \
      "spy_to_be_unmocked" "was never registered as a spy; call it first with" \
      "bashunit::spy spy_to_be_unmocked")" \
    "$(assert_not_called spy_to_be_unmocked)"
}

function test_assert_not_called_still_passes_on_a_registered_spy() {
  bashunit::spy spy_never_invoked

  assert_empty "$(assert_not_called spy_never_invoked)"
  assert_empty "$(assert_have_been_called_times 0 spy_never_invoked)"
}

function test_spy_on_echo_does_not_hang() {
  source ./tests/functional/fixtures/echo_function.sh
  bashunit::spy echo

  write_message "hello world"

  assert_have_been_called echo
}

function test_spy_on_printf_does_not_hang() {
  source ./tests/functional/fixtures/printf_function.sh
  bashunit::spy printf

  format_message "hello world"

  assert_have_been_called printf
}
