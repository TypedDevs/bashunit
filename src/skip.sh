#!/bin/bash

function skip() {
  local label="${1:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  console_results::print_skipped_test "${label}"

  state::add_assertions_skipped
}
