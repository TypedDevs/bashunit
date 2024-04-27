#!/bin/bash

_TEST_MULTI_INVOKER_ITERATION_FILE=""

function set_up_before_script() {
  _TEST_MULTI_INVOKER_ITERATION_FILE=$(mktemp)
  echo 0 > "$_TEST_MULTI_INVOKER_ITERATION_FILE"
}

function tear_down_after_script() {
  rm "$_TEST_MULTI_INVOKER_ITERATION_FILE"
}

# multi_invoker invoker_test_numbers
function test_multi_invoker_simple() {
  local current_number="$1"
  local second_arg="$2"
  local third_arg="$3"

  local current_iteration=0

  echo "$(awk 'BEGIN{FS=OFS=""} {$1++} {print $1}' "$_TEST_MULTI_INVOKER_ITERATION_FILE")"\
    > "$_TEST_MULTI_INVOKER_ITERATION_FILE"
  current_iteration=$(cat "$_TEST_MULTI_INVOKER_ITERATION_FILE")

  case $current_iteration in
    1)
      assert_equals "one" "$current_number"
      assert_empty "$third_arg"
      ;;
    2)
      assert_equals "two" "$current_number"
      assert_empty "$third_arg"
      ;;
    3)
      assert_equals "three" "$current_number"
      assert_equals "more" "$third_arg"
      ;;
    *)
      exit 1
      ;;
  esac
  assert_equals "mississippi" "$second_arg"
}

# multi_invoker invoker_test_whitespace
function test_multi_invoker_whitespace() {
  local first_arg="$1"
  local second_arg="$2"
  local current_iteration=0

  echo "$(awk 'BEGIN{FS=OFS=""} {$1++} {print $1}' "$_TEST_MULTI_INVOKER_ITERATION_FILE")"\
    > "$_TEST_MULTI_INVOKER_ITERATION_FILE"
  current_iteration=$(cat "$_TEST_MULTI_INVOKER_ITERATION_FILE")

  assert_equals "this arg" "$first_arg"

  case $current_iteration in
    4)
      assert_equals "has spaces" "$second_arg"
      ;;
    5)
      assert_equals "$(printf "has\na newline")" "$second_arg"
      ;;
    *)
      fail
      ;;
  esac
}

function invoker_test_numbers() {
    run_test one mississippi
    run_test two mississippi
    run_test three mississippi more
}

function invoker_test_whitespace() {
    run_test "this arg" "has spaces"
    run_test "this arg" "$(printf "has\na newline")"
}