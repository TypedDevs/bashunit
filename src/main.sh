#!/bin/bash

function main::exec_tests() {
  local filter=$1
  local files=("${@:2}") # Store all arguments starting from the second as an array

  console_header::print_version_with_env
  runner::load_test_files "$filter" "${files[@]}"
  console_results::render_result
  exit 0
}

function main::exec_assert() {
  local assert_fn=$1
  local args=("${@:2}") # Store all arguments starting from the second as an array

  "$assert_fn" "${args[@]}"
  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
      exit 1
  fi
}
