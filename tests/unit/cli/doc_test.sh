#!/usr/bin/env bash

# shellcheck disable=SC2155

function test_print_asserts_outputs_assertion_names() {
  bashunit::mock bashunit::doc::get_embedded_docs \
    cat ./tests/unit/fixtures/doc_sample.md

  local output
  output=$(bashunit::doc::print_asserts)

  assert_contains "assert_equals" "$output"
  assert_contains "assert_contains" "$output"
}

function test_print_asserts_with_filter_matches() {
  bashunit::mock bashunit::doc::get_embedded_docs \
    cat ./tests/unit/fixtures/doc_sample.md

  local output
  output=$(bashunit::doc::print_asserts "contains")

  assert_contains "assert_contains" "$output"
  assert_not_contains "assert_equals" "$output"
}

function test_print_asserts_with_no_matching_filter() {
  bashunit::mock bashunit::doc::get_embedded_docs \
    cat ./tests/unit/fixtures/doc_sample.md

  local output
  output=$(bashunit::doc::print_asserts "nonexistent")

  assert_empty "$output"
}

function test_print_asserts_strips_markdown_links() {
  bashunit::mock bashunit::doc::get_embedded_docs \
    cat ./tests/unit/fixtures/doc_sample.md

  local output
  output=$(bashunit::doc::print_asserts "contains")

  assert_not_contains "[" "$output"
  assert_not_contains "]" "$output"
}

function test_get_embedded_docs_returns_content() {
  local output
  output=$(bashunit::doc::get_embedded_docs)

  assert_not_empty "$output"
}
