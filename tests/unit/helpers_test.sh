#!/bin/bash

function test_normalizeTestFunctionName_empty() {
  assertEquals "" "$(normalizeTestFunctionName)"
}

function test_normalizeTestFunctionName_one_word() {
  assertEquals "Word" "$(normalizeTestFunctionName "word")"
}

function test_normalizeTestFunctionName_snake_case() {
  assertEquals "Some logic" "$(normalizeTestFunctionName "test_some_logic")"
}

function test_normalizeTestFunctionName_camel_case() {
  assertEquals "SomeLogic" "$(normalizeTestFunctionName "testSomeLogic")"
}

function test_getFunctionsToRun_no_filter_should_return_all_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  local result1
  result1=$(getFunctionsToRun "prefix" "" "${functions[*]}")
  assertEquals "prefix_function1 prefix_function2 prefix_function3" "$result1"
}

function test_getFunctionsToRun_with_filter_should_return_matching_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  local result2
  result2=$(getFunctionsToRun "prefix" "function1" "${functions[*]}")
  assertEquals "prefix_function1" "$result2"
}

function test_getFunctionsToRun_filter_no_matching_functions_should_return_empty() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  local result3
  result3=$(getFunctionsToRun "prefix" "nonexistent" "${functions[*]}")
  assertEquals "" "$result3"
}

function test_getFunctionsToRun_fail_when_duplicates() {
  local functions=("prefix_function1" "prefix_function1")

  assertGeneralError "$(getFunctionsToRun "prefix" "" "${functions[*]}")"
}
