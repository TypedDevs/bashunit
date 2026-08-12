#!/usr/bin/env bash

# bashunit::mock returns one fixed answer forever, which cannot express the
# code that most needs a double: retry loops, polling and backoff.

function test_a_sequence_of_exit_codes_is_consumed_in_order() {
  bashunit::mock_sequence a_flaky_command 1 1 0

  local first=0 second=0 third=0
  a_flaky_command || first=$?
  a_flaky_command || second=$?
  a_flaky_command || third=$?

  assert_same "1 1 0" "$first $second $third"
}

function test_bodies_and_exit_codes_mix_in_one_sequence() {
  bashunit::mock_sequence a_mixed_command 1 "echo recovered"

  local code=0
  a_mixed_command >/dev/null || code=$?

  assert_same "1" "$code"
  assert_same "recovered" "$(a_mixed_command)"
}

# Documented: the last entry repeats once the sequence is exhausted, so a test
# that calls one more time than it planned does not get a surprise.
function test_the_last_entry_repeats_once_the_sequence_is_exhausted() {
  bashunit::mock_sequence an_exhausted_command 1 0

  local codes=""
  local remaining=4
  while [ "$remaining" -gt 0 ]; do
    remaining=$((remaining - 1))
    local code=0
    an_exhausted_command || code=$?
    codes="$codes$code"
  done

  assert_same "1000" "$codes"
}

function test_a_single_entry_sequence_behaves_like_a_plain_mock() {
  bashunit::mock_sequence a_single_command 3

  local first=0 second=0
  a_single_command || first=$?
  a_single_command || second=$?

  assert_same "3 3" "$first $second"
}

function test_arguments_reach_a_body_entry() {
  bashunit::mock_sequence an_echoing_command "echo called with"

  assert_same "called with a b" "$(an_echoing_command a b)"
}

function test_unmock_clears_a_sequenced_mock() {
  bashunit::mock_sequence an_unmocked_command 1 0
  bashunit::unmock an_unmocked_command

  local defined="no"
  if declare -F an_unmocked_command >/dev/null 2>&1; then
    defined="yes"
  fi

  assert_same "no" "$defined"
}

function test_a_spy_over_a_sequenced_mock_records_every_call() {
  bashunit::spy a_spied_command
  bashunit::mock_sequence a_spied_command 1 0

  a_spied_command first || true
  a_spied_command second || true

  assert_have_been_called_times 2 a_spied_command
  assert_have_been_called_with a_spied_command "second"
}

function test_a_sequence_does_not_leak_into_the_next_test() {
  # The counterpart of the test below: this one arms the sequence, the next
  # one asserts the runner unwound it.
  bashunit::mock_sequence a_leaking_command 1 0

  local code=0
  a_leaking_command || code=$?

  assert_same "1" "$code"
}

function test_z_the_previous_sequence_is_gone() {
  local defined="no"
  if declare -F a_leaking_command >/dev/null 2>&1; then
    defined="yes"
  fi

  assert_same "no" "$defined"
}
