#!/usr/bin/env bash
# shellcheck disable=SC2009
# shellcheck disable=SC2317
# shellcheck disable=SC2329

function tear_down() {
  unset code
  unset ps
}

function set_up() {
  function code() {
    ps a | grep apache
  }
}

function test_successful_mock() {
  bashunit::mock ps <<EOF
PID TTY          TIME CMD
13525 pts/7    00:00:01 bash
24162 pts/7    00:00:00 ps
8387  ?        00:00:00 /usr/sbin/apache2 -k start
EOF

  assert_empty "$(assert_successful_code "$(code)")"
}

function test_successful_override_ps_with_echo_with_mock() {
  bashunit::mock ps echo hello world
  assert_same "hello world" "$(ps)"
}

function test_successful_spy() {
  bashunit::spy ps
  ps a_random_parameter_1 a_random_parameter_2

  assert_have_been_called_with ps "a_random_parameter_1 a_random_parameter_2"
  assert_have_been_called ps
}

function test_unsuccessful_spy_called() {
  bashunit::spy ps

  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful spy called" "ps" "to have been called" "once")" \
    "$(assert_have_been_called ps)"
}

function test_successful_spy_called_times() {
  bashunit::spy ps

  ps
  ps

  assert_have_been_called_times 2 ps
}

function test_unsuccessful_spy_called_times() {
  bashunit::spy ps

  ps
  ps

  bashunit::spy::call_log_to_slot ps

  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful spy called times" "ps" \
    "to have been called" "1 times" \
    "actual" "2 times" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
    "$(assert_have_been_called_times 1 ps)"
}

function test_successful_spy_with_source_function() {
  # shellcheck source=/dev/null
  source "$(bashunit::current_dir)/../fixtures/fake_function_to_spy.sh"
  bashunit::spy function_to_be_spied_on

  function_to_be_spied_on

  assert_have_been_called function_to_be_spied_on
}

function test_unsuccessful_spy_with_source_function_have_been_called() {
  # shellcheck source=/dev/null
  source "$(bashunit::current_dir)/../fixtures/fake_function_to_spy.sh"
  bashunit::spy function_to_be_spied_on

  function_to_be_spied_on
  function_to_be_spied_on

  bashunit::spy::call_log_to_slot function_to_be_spied_on

  assert_same "$(bashunit::console_results::print_failed_test \
    "Unsuccessful spy with source function have been called" \
    "function_to_be_spied_on" \
    "to have been called" "1 times" \
    "actual" "2 times" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
    "$(assert_have_been_called_times 1 function_to_be_spied_on)"
}

function test_successful_spy_called_times_with_source() {
  # shellcheck source=/dev/null
  source "$(bashunit::current_dir)/../fixtures/fake_function_to_spy.sh"
  bashunit::spy function_to_be_spied_on

  function_to_be_spied_on
  function_to_be_spied_on

  assert_have_been_called_times 2 function_to_be_spied_on
}

function test_spy_called_in_subshell() {
  bashunit::spy spy_called_in_subshell

  function run() {
    spy_called_in_subshell "$1"
    spy_called_in_subshell "$1"
    echo "done"
  }

  local result
  result="$(run "2025-05-23")"

  assert_same "done" "$result"
  assert_have_been_called spy_called_in_subshell
  assert_have_been_called_times 2 spy_called_in_subshell
  assert_have_been_called_with spy_called_in_subshell "2025-05-23"
}

function test_mock_called_in_subshell() {
  bashunit::mock date echo "2024-05-01"

  function run() {
    date
  }

  local result
  result="$(run)"

  assert_same "2024-05-01" "$result"
}

function test_spy_serialize_args_joins_quoted_arguments_with_a_unit_separator() {
  bashunit::spy::serialize_args_to_slot "a b" c

  assert_same "a\\ b"$'\x1f'"c" "$_BASHUNIT_SPY_SERIALIZED_OUT"
}

function test_spy_call_log_renders_every_recorded_call() {
  bashunit::spy spy_with_two_calls

  spy_with_two_calls first
  spy_with_two_calls second a

  bashunit::spy::call_log_to_slot spy_with_two_calls

  assert_same "    ${_BASHUNIT_COLOR_FAINT}Recorded calls to 'spy_with_two_calls' (2):\
${_BASHUNIT_COLOR_DEFAULT}
      ${_BASHUNIT_COLOR_FAINT}1:${_BASHUNIT_COLOR_DEFAULT} first
      ${_BASHUNIT_COLOR_FAINT}2:${_BASHUNIT_COLOR_DEFAULT} second a" \
    "$_BASHUNIT_SPY_CALL_LOG_OUT"
}

function test_spy_call_log_caps_the_dump_with_an_explicit_marker() {
  bashunit::spy spy_called_many_times

  local i=1
  while [ "$i" -le 13 ]; do
    spy_called_many_times "call$i"
    i=$((i + 1))
  done

  bashunit::spy::call_log_to_slot spy_called_many_times

  assert_contains "      ${_BASHUNIT_COLOR_FAINT}10:${_BASHUNIT_COLOR_DEFAULT} call10" \
    "$_BASHUNIT_SPY_CALL_LOG_OUT"
  assert_not_contains "call11" "$_BASHUNIT_SPY_CALL_LOG_OUT"
  assert_contains "… and 3 more" "$_BASHUNIT_SPY_CALL_LOG_OUT"
}

function test_spy_call_log_is_empty_without_recorded_calls() {
  bashunit::spy spy_without_calls

  bashunit::spy::call_log_to_slot spy_without_calls
  assert_empty "$_BASHUNIT_SPY_CALL_LOG_OUT"

  bashunit::spy::call_log_to_slot never_spied_at_all
  assert_empty "$_BASHUNIT_SPY_CALL_LOG_OUT"
}

function test_spy_call_log_keeps_argument_boundaries_in_args_mode() {
  bashunit::spy spy_with_spaced_argument

  spy_with_spaced_argument "a b"

  bashunit::spy::call_log_to_slot spy_with_spaced_argument args

  assert_contains "1:${_BASHUNIT_COLOR_DEFAULT} a\\ b" "$_BASHUNIT_SPY_CALL_LOG_OUT"
}

function test_spy_called_with_different_arguments() {
  bashunit::spy ps

  ps first_a first_b
  ps second

  assert_have_been_called_with ps "first_a first_b" 1
  assert_have_been_called_with ps "second" 2
}

function test_spy_successful_not_called() {
  bashunit::spy ps

  assert_not_called ps
}

function test_spy_unsuccessful_not_called() {
  bashunit::spy ps

  ps

  bashunit::spy::call_log_to_slot ps

  assert_same \
    "$(bashunit::console_results::print_failed_test "Spy unsuccessful not called" "ps" \
      "to have been called" "0 times" \
      "actual" "1 times" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
    "$(assert_not_called ps)"
}

function test_spy_with_pipe_in_arguments() {
  # Skip when coverage is enabled because coverage uses grep internally,
  # which interferes with spying on grep
  if bashunit::env::is_coverage_enabled; then
    bashunit::skip "Cannot spy on grep when coverage is enabled"
    return
  fi

  bashunit::spy grep

  grep -E 'foo|bar'

  assert_have_been_called_with grep '-E foo|bar'
}

function test_successful_spy_nth_called_with() {
  bashunit::spy ps

  ps first_a first_b
  ps second
  ps third

  assert_have_been_called_nth_with 1 ps "first_a first_b"
  assert_have_been_called_nth_with 2 ps "second"
  assert_have_been_called_nth_with 3 ps "third"
}

function test_unsuccessful_spy_nth_called_with() {
  bashunit::spy ps

  ps first
  ps second

  bashunit::spy::call_log_to_slot ps

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful spy nth called with" \
      "wrong" "but got " "first" "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
    "$(assert_have_been_called_nth_with 1 ps "wrong")"
}

function test_unsuccessful_spy_nth_called_with_invalid_index() {
  bashunit::spy ps

  ps first

  bashunit::spy::call_log_to_slot ps

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful spy nth called with invalid index" \
      "expected call" "at index 5 but" "only called 1 times" \
      "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT")" \
    "$(assert_have_been_called_nth_with 5 ps "first")"
}



function test_spy_with_exit_code_returns_specified_exit_code() {
  bashunit::spy ps 1

  local actual_exit_code=0
  ps || actual_exit_code=$?

  assert_have_been_called ps
  assert_same "1" "$actual_exit_code"
}

function test_spy_with_exit_code_zero_returns_zero() {
  bashunit::spy ps 0

  ps
  local actual_exit_code=$?

  assert_have_been_called ps
  assert_same "0" "$actual_exit_code"
}

function test_spy_with_impl_calls_custom_function() {
  custom_ps_impl() {
    builtin echo "custom output"
  }
  export -f custom_ps_impl

  bashunit::spy ps custom_ps_impl

  local output
  output=$(ps)

  assert_have_been_called ps
  assert_same "custom output" "$output"
}

function test_spy_times_to_slot_reports_zero_when_never_spied() {
  bashunit::spy::times_to_slot "never_spied_command"

  assert_same "0" "$_BASHUNIT_SPY_TIMES_OUT"
}

function test_spy_times_to_slot_reports_recorded_call_count() {
  bashunit::spy ps

  ps
  ps
  ps

  bashunit::spy::times_to_slot ps

  assert_same "3" "$_BASHUNIT_SPY_TIMES_OUT"
}

function test_spy_with_impl_records_calls_and_delegates() {
  custom_ps_impl() {
    builtin echo "delegated"
  }
  export -f custom_ps_impl

  bashunit::spy ps custom_ps_impl

  ps first
  ps second

  assert_have_been_called_times 2 ps
  assert_have_been_called_nth_with 1 ps "first"
  assert_have_been_called_nth_with 2 ps "second"
}
