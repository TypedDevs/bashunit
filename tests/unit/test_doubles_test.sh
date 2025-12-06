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
  bashunit::mock ps<<EOF
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

  assert_same\
    "$(console_results::print_failed_test "Unsuccessful spy called" "ps" "to have been called" "once")"\
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

  assert_same\
    "$(console_results::print_failed_test "Unsuccessful spy called times" "ps" \
    "to have been called" "1 times" \
    "actual" "2 times")"\
    "$(assert_have_been_called_times 1 ps)"
}

function test_successful_spy_with_source_function() {
    # shellcheck source=/dev/null
    source ./fixtures/fake_function_to_spy.sh
    bashunit::spy function_to_be_spied_on

    function_to_be_spied_on

    assert_have_been_called function_to_be_spied_on
}

function test_unsuccessful_spy_with_source_function_have_been_called() {
  # shellcheck source=/dev/null
  source ./fixtures/fake_function_to_spy.sh
  bashunit::spy function_to_be_spied_on

  function_to_be_spied_on
  function_to_be_spied_on

  assert_same\
    "$(console_results::print_failed_test \
    "Unsuccessful spy with source function have been called"\
    "function_to_be_spied_on" \
    "to have been called" "1 times" \
    "actual" "2 times")"\
    "$(assert_have_been_called_times 1 function_to_be_spied_on)"
}


function test_successful_spy_called_times_with_source() {
  # shellcheck source=/dev/null
  source ./fixtures/fake_function_to_spy.sh
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

  assert_same \
    "$(console_results::print_failed_test "Spy unsuccessful not called" "ps" \
      "to have been called" "0 times" \
      "actual" "1 times")" \
    "$(assert_not_called ps)"
}

function test_spy_with_pipe_in_arguments() {
  bashunit::spy grep

  grep -E 'foo|bar'

  assert_have_been_called_with grep '-E foo|bar'
}
