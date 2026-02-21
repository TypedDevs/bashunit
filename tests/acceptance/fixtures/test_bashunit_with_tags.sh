#!/usr/bin/env bash

# @tag slow
function test_slow_operation() {
  assert_same 1 1
}

# @tag fast
function test_fast_operation() {
  assert_same 2 2
}

# @tag slow
# @tag database
function test_slow_database_query() {
  assert_same 3 3
}

function test_no_tags() {
  assert_same 4 4
}
