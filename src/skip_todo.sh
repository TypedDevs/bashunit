#!/usr/bin/env bash

function bashunit::skip() {
  local reason=${1-}
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  console_results::print_skipped_test "${label}" "${reason}"

  bashunit::state::add_assertions_skipped
}

function bashunit::todo() {
  local pending=${1-}
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  console_results::print_incomplete_test "${label}" "${pending}"

  bashunit::state::add_assertions_incomplete
}
