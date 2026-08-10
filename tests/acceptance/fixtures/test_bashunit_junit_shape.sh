#!/usr/bin/env bash

# One passing test that prints output (feeds <system-out>) and one failing
# test in the same file, so the JUnit report has a suite with both counts.
function test_junit_pass_with_output() {
  echo "hello from the test body"
  assert_same "ok" "ok"
}

function test_junit_fail() {
  assert_same "expected junit value" "actual junit value"
}
