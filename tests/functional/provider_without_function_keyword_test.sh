#!/usr/bin/env bash
set -euo pipefail

# Test case for issue #586: data providers should work without the function keyword
# All test functions and providers defined WITHOUT the function keyword

# @data_provider provide_test_data_1
test_should_work_without_function_keyword_1() {
  local input="$1"
  local expected="$2"

  assert_equals "$expected" "$input"
}

provide_test_data_1() {
  echo "value1" "value1"
  echo "value2" "value2"
}

# @data_provider provide_test_data_2
test_should_work_without_function_keyword_2() {
  local input="$1"

  assert_not_equals "invalid" "$input"
}

provide_test_data_2() {
  echo "first"
  echo "second"
}

# @data_provider provide_test_data_3
test_should_work_without_function_keyword_3() {
  local value="$1"

  assert_matches "^test" "$value"
}

provide_test_data_3() {
  bashunit::data_set "test1"
  bashunit::data_set "test2"
  bashunit::data_set "test3"
}
