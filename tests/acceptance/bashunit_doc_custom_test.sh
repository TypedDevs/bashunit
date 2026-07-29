#!/usr/bin/env bash

BOOT="tests/acceptance/fixtures/custom_assert_docs.sh"

function test_doc_custom_lists_the_project_assertions() {
  local output
  output=$(./bashunit doc --custom --boot "$BOOT" 2>&1) || true

  assert_contains "## assert_positive_number" "$output"
  assert_contains "## assert_http_success" "$output"
}

function test_doc_custom_renders_the_leading_comment_block() {
  local output
  output=$(./bashunit doc --custom --boot "$BOOT" 2>&1) || true

  assert_contains "Asserts that the value is a number greater than zero." "$output"
  assert_contains "Arguments: \$1 - the value under test" "$output"
  assert_contains "Asserts that the status code is a 2xx." "$output"
}

function test_doc_custom_skips_functions_that_are_not_assertions() {
  local output
  output=$(./bashunit doc --custom --boot "$BOOT" 2>&1) || true

  assert_not_contains "helper_not_an_assertion" "$output"
}

function test_doc_custom_does_not_list_the_built_in_assertions() {
  local output
  output=$(./bashunit doc --custom --boot "$BOOT" 2>&1) || true

  assert_not_contains "## assert_same" "$output"
  assert_not_contains "## assert_line_count" "$output"
}

function test_doc_custom_without_a_bootstrap_reports_none() {
  local output
  output=$(./bashunit doc --custom 2>&1) || true

  assert_contains "No custom assertions" "$output"
}

function test_doc_custom_without_a_bootstrap_still_exits_zero() {
  local exit_code=0

  ./bashunit doc --custom >/dev/null 2>&1 || exit_code=$?

  assert_same "0" "$exit_code"
}

function test_doc_appends_a_custom_section_when_a_bootstrap_defines_any() {
  local output
  output=$(./bashunit doc --boot "$BOOT" 2>&1) || true

  # Built-in catalogue still there, custom section appended after it.
  assert_contains "## assert_same" "$output"
  assert_contains "Custom assertions" "$output"
  assert_contains "## assert_positive_number" "$output"
}

function test_doc_without_a_bootstrap_has_no_custom_section() {
  local output
  output=$(./bashunit doc 2>&1) || true

  assert_not_contains "Custom assertions" "$output"
}

function test_doc_custom_honours_a_filter() {
  local output
  output=$(./bashunit doc --custom --boot "$BOOT" http 2>&1) || true

  assert_contains "## assert_http_success" "$output"
  assert_not_contains "## assert_positive_number" "$output"
}

function test_doc_custom_reports_an_unreadable_bootstrap() {
  local output
  output=$(./bashunit doc --custom --boot "does/not/exist.sh" 2>&1) || true

  assert_contains "cannot read the bootstrap file" "$output"
}
