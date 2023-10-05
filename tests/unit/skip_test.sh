#!/bin/bash

#function test_skip() {
#  skip
#
#  assert_have_been_called_times 1 console_results::print_skipped_test
#  assert_have_been_called_times 1 state::add_assertions_skipped
#}

function test_skip_output() {
  assert_equals\
    "$(console_results::print_skipped_test "Skip output")"\
    "$(skip)"
}
