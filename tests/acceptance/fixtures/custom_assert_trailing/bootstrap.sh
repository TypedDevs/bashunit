#!/usr/bin/env bash

# bashunit::assert_that returns 1 on failure so it can be chained. A custom
# assertion that ends with it therefore returns 1 too.
function assert_positive_number() {
  bashunit::assert_that "positive number" "$1" test "$1" -gt 0
}
