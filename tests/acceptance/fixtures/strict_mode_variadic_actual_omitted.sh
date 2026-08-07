#!/usr/bin/env bash

# The "actual" operand of these assertions is variadic ("${@:2}"), so omitting
# it leaves an empty array. Expanding an empty array under `set -u` (--strict)
# is an unbound-variable error on Bash < 4.4, which used to abort the test. The
# assertions now reject the missing operand as a usage error first.
function test_contains_without_actual() {
  assert_contains "needle"
}

function test_string_starts_with_without_actual() {
  assert_string_starts_with "prefix"
}
