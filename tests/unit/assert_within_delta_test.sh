#!/usr/bin/env bash
function test_assert_within_delta_pass() {
  assert_within_delta 3.14 3.14159 0.01
}
function test_assert_within_delta_abs() {
  assert_within_delta 105 100 10
}
