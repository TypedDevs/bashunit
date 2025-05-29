#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  _GLOBAL="aa-bb"
}

# @data_provider provide_multiples_values
function test_multiple_values_from_data_provider() {
  local first=$1
  local second=$2

  assert_equals "${_GLOBAL}" "$first-$second"
}

function provide_multiples_values() {
  echo "aa" "bb"
}

# @data_provider provide_single_values
function test_single_values_from_data_provider() {
  local data="$1"

  assert_not_equals "zero" "$data"
}

function provide_single_values() {
  echo "one"
  echo "two"
  echo "three"
}

# @data_provider provide_single_value
function test_single_value_from_data_provider() {
  local current_data="$1"

  assert_same "one" "$current_data"
}

function provide_single_value() {
  echo "one"
}
