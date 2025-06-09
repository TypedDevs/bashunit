#!/usr/bin/env bash

function tear_down() {
  export BASHUNIT_PARALLEL_RUN=$original_parallel_run
}

function set_up() {
  original_parallel_run=$BASHUNIT_PARALLEL_RUN
  export BASHUNIT_PARALLEL_RUN=true
}

function test_parallel_enabled_on_windows() {
  mock check_os::is_windows mock_true
  mock check_os::is_macos mock_false
  mock check_os::is_ubuntu mock_false

  assert_successful_code "$(parallel::is_enabled)"
}
