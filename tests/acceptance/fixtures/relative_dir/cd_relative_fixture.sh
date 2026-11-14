#!/usr/bin/env bash

function set_up_before_script() {
  cd "$(bashunit::current_dir)" || return
}

function test_runs_from_the_test_file_directory() {
  assert_file_exists ./lib.sh
}
