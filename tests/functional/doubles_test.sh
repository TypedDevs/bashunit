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
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 1 ]]; then
    bashunit::skip "Spies don't work for external scripts in Bash 3.0"
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
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 1 ]]; then
    bashunit::skip "Spies don't work for external scripts in Bash 3.0"
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
