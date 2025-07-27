#!/usr/bin/env bash

function test_fail_with_old_bash_version() {
  output=$(BASHUNIT_TEST_BASH_VERSION=3.1 ./bashunit --version 2>&1)
  exit_code=$?
  assert_contains "Bashunit requires Bash >= 3.2. Current version: 3.1" "$output"
  assert_general_error "$output" "" "$exit_code"
}
