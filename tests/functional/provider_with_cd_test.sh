#!/usr/bin/env bash
set -euo pipefail

# Regression test for https://github.com/TypedDevs/bashunit/issues/529
# Data providers should work even when set_up_before_script changes directory

function set_up_before_script() {
  cd "$(temp_dir)" || return 1
}

# @data_provider provide_data
function test_data_provider_works_after_cd_in_set_up_before_script() {
  local value="$1"

  assert_equals "expected_value" "$value"
}

function provide_data() {
  echo "expected_value"
}
