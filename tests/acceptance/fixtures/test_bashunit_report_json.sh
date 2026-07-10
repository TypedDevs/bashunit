#!/usr/bin/env bash

function test_json_pass() {
  assert_same "ok" "ok"
}

# The failure message contains a double quote, exercising JSON string escaping.
function test_json_fail_with_quote() {
  assert_same 'a"b' 'c'
}
