#!/usr/bin/env bash
# Fixture for provider-map scanner tests. Not run as a suite; scanned as text.

# @data_provider provide_at_form
function test_with_at_annotation() {
  return 0
}

# data_provider provide_plain_form
function test_without_at() {
  return 0
}

# @data_provider provide_two_lines_up
# shellcheck disable=SC2317
function test_annotation_two_lines_up() {
  return 0
}

# @data_provider provide_shared
function test_shares_provider_one() {
  return 0
}

# @data_provider provide_shared
test_shares_provider_two() {
  return 0
}

function test_without_provider() {
  return 0
}
