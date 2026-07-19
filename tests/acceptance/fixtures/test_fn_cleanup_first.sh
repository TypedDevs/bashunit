#!/usr/bin/env bash
set -euo pipefail

# Regression fixture for https://github.com/TypedDevs/bashunit/issues/829
# First file: defines a marker test function that must not leak into the
# main shell once this file has been processed.

function test_fn_cleanup_marker_from_first_file() {
  assert_equals "first" "first"
}
