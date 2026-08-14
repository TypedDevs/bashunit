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

  bashunit::spy::call_log_to_slot spy_boundary_command args

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Spy call with args detects wrong argument boundaries" \
      "a b" "but got " "a\\ b" "compared" "the only call" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
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

function test_failed_call_assertions_dump_the_recorded_calls() {
  bashunit::spy spy_with_a_call_log

  spy_with_a_call_log first
  spy_with_a_call_log second

  bashunit::spy::call_log_to_slot spy_with_a_call_log
  local log=$_BASHUNIT_SPY_CALL_LOG_OUT
  local label="Failed call assertions dump the recorded calls"

  assert_same \
    "$(bashunit::console_results::print_failed_test "$label" \
      "first" "but got " "second" "compared" "the last of 2 calls" "$log")" \
    "$(assert_have_been_called_with spy_with_a_call_log "first")"

  assert_same \
    "$(bashunit::console_results::print_failed_test "$label" \
      "spy_with_a_call_log" "to have been called" "0 times" "actual" "2 times" "$log")" \
    "$(assert_not_called spy_with_a_call_log)"

  assert_same \
    "$(bashunit::console_results::print_failed_test "$label" \
      "first" "but got " "second" "" "" "$log")" \
    "$(assert_have_been_called_nth_with 2 spy_with_a_call_log "first")"
}

function test_called_with_any_matches_a_call_in_any_position() {
  bashunit::spy spy_called_three_times

  spy_called_three_times first
  spy_called_three_times middle one
  spy_called_three_times last

  assert_empty "$(assert_have_been_called_with_any spy_called_three_times "first" 2>&1)"
  assert_empty "$(assert_have_been_called_with_any spy_called_three_times "middle one" 2>&1)"
  assert_empty "$(assert_have_been_called_with_any spy_called_three_times "last" 2>&1)"
}

function test_called_with_any_fails_when_no_call_matches() {
  bashunit::spy spy_without_a_match

  spy_without_a_match first
  spy_without_a_match second

  bashunit::spy::call_log_to_slot spy_without_a_match

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Called with any fails when no call matches" \
      "third" "not found in any of" "2 calls" "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
    "$(assert_have_been_called_with_any spy_without_a_match "third")"
}

function test_called_with_reports_which_call_it_compared() {
  bashunit::spy spy_compared_call

  spy_compared_call first
  spy_compared_call second

  bashunit::spy::call_log_to_slot spy_compared_call
  local log=$_BASHUNIT_SPY_CALL_LOG_OUT
  local label="Called with reports which call it compared"

  assert_same \
    "$(bashunit::console_results::print_failed_test "$label" \
      "third" "but got " "second" "compared" "the last of 2 calls" "$log")" \
    "$(assert_have_been_called_with spy_compared_call "third")"

  assert_same \
    "$(bashunit::console_results::print_failed_test "$label" \
      "third" "but got " "first" "compared" "call 1 of 2" "$log")" \
    "$(assert_have_been_called_with spy_compared_call "third" 1)"
}

function test_passing_call_assertions_print_nothing() {
  bashunit::spy spy_with_a_passing_assertion

  spy_with_a_passing_assertion first

  assert_empty "$(assert_have_been_called spy_with_a_passing_assertion)"
  assert_empty "$(assert_have_been_called_times 1 spy_with_a_passing_assertion)"
  assert_empty "$(assert_have_been_called_with spy_with_a_passing_assertion "first")"
}

function test_mock_with_an_exit_code_returns_it_without_output() {
  bashunit::mock mock_failing_command 1

  local code=0
  local output
  output="$(mock_failing_command 2>&1)" || code=$?

  assert_same "1" "$code"
  assert_empty "$output"
}

function test_mock_with_the_exit_code_zero_returns_zero() {
  bashunit::mock mock_succeeding_command 0

  local code=1
  mock_succeeding_command && code=0

  assert_same "0" "$code"
}

function test_mock_keeps_the_replacement_implementation_form() {
  bashunit::mock mock_with_impl echo hello

  assert_same "hello" "$(mock_with_impl)"
}

function test_mock_reads_only_a_lone_all_digits_argument_as_an_exit_code() {
  # `echo 1` is an implementation whose first word happens to be a command, so
  # the digits must stay an argument to it rather than becoming `return 1`.
  bashunit::mock mock_with_numeric_argument echo 1

  local code=1
  local output
  output="$(mock_with_numeric_argument)" && code=0

  assert_same "1" "$output"
  assert_same "0" "$code"
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

# Retry logic is the code that most needs a double and could not be doubled:
# "fail twice, then succeed" used to mean a hand-rolled counter file per test.
function retry_until_success() { # $1 = attempts
  local attempts=$1
  local i=0
  while [ "$i" -lt "$attempts" ]; do
    i=$((i + 1))
    if an_unreliable_service; then
      builtin echo "$i"
      return 0
    fi
  done
  return 1
}

function test_a_sequence_drives_a_retry_loop() {
  bashunit::mock_sequence an_unreliable_service 1 1 0

  assert_same "3" "$(retry_until_success 5)"
}

function test_a_retry_loop_gives_up_when_the_sequence_never_succeeds() {
  bashunit::mock_sequence an_unreliable_service 1

  local code=0
  retry_until_success 3 >/dev/null || code=$?

  assert_same "1" "$code"
}

function test_a_destructive_command_is_never_reached() {
  bashunit::spy a_destructive_command
  bashunit::mock_sequence an_unreliable_service 0

  retry_until_success 3 >/dev/null

  assert_have_never_been_called a_destructive_command
}

# All three doubles build the double with `eval "function $command() { … }"`, so
# a name carrying whitespace or shell syntax used to surface as a raw bash
# syntax error pointing at bashunit's internals (#1136). Passing the arguments
# along with the command is the easy way to hit it.
function test_mock_refuses_a_name_with_arguments() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Mock refuses a name with arguments" \
      "ls -l" "is not a usable command name for bashunit::mock; name the command alone, as in" \
      "bashunit::mock ls")" \
    "$(bashunit::mock "ls -l" echo hi)"
}

function test_spy_refuses_a_name_with_shell_syntax() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Spy refuses a name with shell syntax" \
      "foo;bar" "is not a usable command name for bashunit::spy; name the command alone, as in" \
      "bashunit::spy ls")" \
    "$(bashunit::spy "foo;bar")"
}

# The advice named a bare `mock`, which is `command not found` -- the exact rule
# this API's docs stress hardest (#1229). The two tests above pin the wording
# (both sides go through the same renderer, so they hold in every output mode);
# these run the form that wording recommends, which is what string-matching
# alone could never do.
#
# Do not capture the rendered failure here to inspect it: under `--simple`
# `print_line` emits a one-character marker, so the message would be "F".
function test_the_recommended_form_names_the_command_alone() {
  bashunit::mock ls echo hi

  assert_same "hi" "$(ls)"
}

# mock forwards the call's own arguments to the replacement, which is why the
# name never needs to carry them -- the premise of the advice above.
function test_a_mocked_command_still_receives_its_arguments() {
  bashunit::mock ls echo hi

  assert_same "hi -l" "$(ls -l)"
}

# spy takes a single name, so the recommended form is its whole interface.
function test_a_spy_named_alone_records_a_call_with_arguments() {
  bashunit::spy ls

  ls -l

  assert_have_been_called ls
}

# Narrow on purpose: these are legal function names in bash and legitimate
# commands to mock, so the guard must not reject them.
function test_mock_accepts_names_bash_allows() {
  bashunit::mock foo-bar echo one
  bashunit::mock a.b echo two
  bashunit::mock a:b echo three

  assert_same "one" "$(foo-bar)"
  assert_same "two" "$(a.b)"
  assert_same "three" "$(a:b)"
}
