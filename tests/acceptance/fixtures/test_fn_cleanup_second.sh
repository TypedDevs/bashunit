#!/usr/bin/env bash
set -euo pipefail

# Regression fixture for https://github.com/TypedDevs/bashunit/issues/829
# Second file: the first file's test functions must already be unset, so the
# main shell does not grow (and slow down every fork) as files accumulate.

function test_previous_file_test_functions_are_unset() {
  local defined="no"
  if declare -F test_fn_cleanup_marker_from_first_file >/dev/null 2>&1; then
    defined="yes"
  fi
  assert_equals "no" "$defined"
}
