#!/bin/bash

function skip() {
  local reason=${1-}
  local label
  label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"

  console_results::print_skipped_test "${label}" "${reason}"

  state::add_assertions_skipped
}

function todo() {
  local pending=${1-}
  local label
  label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"

  console_results::print_incomplete_test "${label}" "${pending}"

  state::add_assertions_incomplete
}
