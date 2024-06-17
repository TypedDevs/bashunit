#!/bin/bash

function main::exec_tests() {
  local filter=$1
  local files=("${@:2}")

  console_header::print_version_with_env
  runner::load_test_files "$filter" "${files[@]}"
  console_results::render_result
  exit 0
}

function main::exec_assert() {
  local original_assert_fn=$1
  local assert_fn=$original_assert_fn
  local args=("${@:2}")

  if ! type "$assert_fn" > /dev/null 2>&1; then
    # try again using prefix `assert_`
    assert_fn="assert_$assert_fn"
    if ! type "$assert_fn" > /dev/null 2>&1; then
      echo "Function $original_assert_fn does not exist."
      exit 1
    fi
  fi

  "$assert_fn" "${args[@]}" "$assert_fn"

  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
      exit 1
  fi
}
