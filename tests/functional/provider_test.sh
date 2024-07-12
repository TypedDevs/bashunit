#!/bin/bash
set -euo pipefail

_TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE=""

function set_up_before_script() {
  _TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE=$(mktemp)
  echo 0 > "$_TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE"
}

function tear_down_after_script() {
  rm "$_TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE"
}

# data_provider provider_test_data_array
function test_get_data_from_provider_as_array() {
  local current_data="$1"
  local current_iteration=0

  echo "$(awk 'BEGIN{FS=OFS=""} {$1++} {print $1}' "$_TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE")"\
    > "$_TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE"
  current_iteration=$(cat "$_TEST_GET_DATA_FROM_PROVIDER_ITERATION_FILE")

  case $current_iteration in
    1)
      assert_equals "one" "$current_data"
      ;;
    2)
      assert_equals "two" "$current_data"
      ;;
    3)
      assert_equals "three" "$current_data"
      ;;
    *)
      fail
      ;;
  esac
}

# data_provider provider_test_data_single_value
function test_get_data_from_provider_as_single_value() {
  local current_data="$1"

  assert_equals "one" "$current_data"
}

function provider_test_data_array() {
  local data=("one" "two" "three")
  echo "${data[@]}"
}

function provider_test_data_single_value() {
  echo "one"
}
