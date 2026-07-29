#!/usr/bin/env bash

# A composed custom assertion that opts in to being counted and reported once.
function assert_http_success() {
  bashunit::assert_once "a 2xx status" "$1"

  assert_greater_or_equal_than "200" "$1"
  assert_less_than "300" "$1"
}

function test_composed_passes() {
  assert_http_success 200
}

function test_composed_fails() {
  assert_http_success 500
}

function test_composed_in_a_loop_counts_every_call() {
  local code
  for code in 200 201 204; do
    assert_http_success "$code"
  done
}

function test_a_plain_assertion_after_a_composed_one_still_counts() {
  assert_http_success 200
  assert_same "a" "a"
}
