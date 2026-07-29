#!/usr/bin/env bash

# A bootstrap defining project assertions, used to check that `bashunit doc`
# picks them up and renders their leading comment block.

# Asserts that the value is a number greater than zero.
# Arguments: $1 - the value under test
function assert_positive_number() {
  bashunit::assert_that "positive number" "$1" test "$1" -gt 0
}

# Asserts that the status code is a 2xx.
function assert_http_success() {
  bashunit::assert_once "a 2xx status" "$1"

  assert_greater_or_equal_than "200" "$1"
  assert_less_than "300" "$1"
}

# Not an assertion, so it must not be listed.
function helper_not_an_assertion() {
  return 0
}
