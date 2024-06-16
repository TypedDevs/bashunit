#!/bin/bash

function main::exec_tests() {
  local filter=$1
  local files=("${@:2}") # Store all arguments starting from the second as an array

  console_header::print_version_with_env
  runner::load_test_files "$filter" "${files[@]}"
  console_results::render_result
  exit 0
}
