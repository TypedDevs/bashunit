#!/bin/bash

function test_skip_output() {
  assert_equals\
    "$(console_results::print_skipped_test "Skip output")"\
    "$(skip)"
}

function test_skip_output_with_reason() {
  assert_equals\
    "$(console_results::print_skipped_test "Skip output with reason" "Skipped because is skippable.")"\
    "$(skip "Skipped because is skippable.")"
}
