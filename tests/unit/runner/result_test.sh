#!/usr/bin/env bash

# --- get_failure_source_context ----------------------------------------------
# The Source: block exists to point at the assertion that failed inside the
# failing test. A one-line test closes on its own definition line, so the walk
# must take the body from there instead of running into the next function.

function test_failure_source_context_stays_inside_a_one_line_test() {
  local file
  file="$(bashunit::temp_file ctx)"
  printf 'function test_one() { assert_same 1 2; }\nfunction test_two() {\n  assert_same 3 3\n}\n' >"$file"

  local out
  out="$(bashunit::runner::get_failure_source_context "$file" 1)"

  assert_not_contains "assert_same 3 3" "$out"
  assert_contains "assert_same 1 2" "$out"
}

function test_failure_source_context_omits_a_one_line_test_without_asserts() {
  local file
  file="$(bashunit::temp_file ctx)"
  printf 'function test_one() { echo hi; }\nfunction test_two() {\n  assert_same 3 3\n}\n' >"$file"

  local out
  out="$(bashunit::runner::get_failure_source_context "$file" 1)"

  assert_not_contains "assert_same 3 3" "$out"
  assert_empty "$out"
}

function test_failure_source_context_keeps_a_multi_line_test() {
  local file
  file="$(bashunit::temp_file ctx)"
  printf 'function test_one() {\n  assert_same 1 2\n}\nfunction test_two() {\n  assert_same 3 3\n}\n' >"$file"

  local out
  out="$(bashunit::runner::get_failure_source_context "$file" 1)"

  assert_contains "assert_same 1 2" "$out"
  assert_not_contains "assert_same 3 3" "$out"
}

function test_failure_source_context_drops_the_one_line_separator() {
  local file
  file="$(bashunit::temp_file ctx)"
  printf 'function test_one() { assert_same 1 2; }\n' >"$file"

  local out
  out="$(bashunit::runner::get_failure_source_context "$file" 1)"

  assert_contains "assert_same 1 2" "$out"
  assert_not_contains "assert_same 1 2;" "$out"
}

function test_failure_source_context_keeps_a_multi_line_test_whose_definition_ends_in_an_expansion() {
  local file
  file="$(bashunit::temp_file ctx)"
  printf 'function test_one() { local v=${HOME}\n  assert_same 1 2\n}\n' >"$file"

  local out
  out="$(bashunit::runner::get_failure_source_context "$file" 1)"

  assert_contains "assert_same 1 2" "$out"
}
