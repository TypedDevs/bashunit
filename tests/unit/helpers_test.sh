#!/bin/bash

function test_empty_normalizeTestFunctionName() {
  assertEquals "" "$(normalizeTestFunctionName)"
}

function test_one_word_normalizeTestFunctionName() {
  assertEquals "Word" "$(normalizeTestFunctionName "word")"
}

function test_snake_case_normalizeTestFunctionName() {
  assertEquals "Some logic" "$(normalizeTestFunctionName "test_some_logic")"
}

function test_camel_case_normalizeTestFunctionName() {
  assertEquals "SomeLogic" "$(normalizeTestFunctionName "testSomeLogic")"
}
