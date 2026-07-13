#!/usr/bin/env bash

function test_diff_multiline_mismatch() {
  assert_same "$(printf 'alpha\nbeta\ngamma')" "$(printf 'alpha\nDELTA\ngamma')"
}

function test_diff_single_line_mismatch() {
  assert_same "expected_value" "actual_value"
}
