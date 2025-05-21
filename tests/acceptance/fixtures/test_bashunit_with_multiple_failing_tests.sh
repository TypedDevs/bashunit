#!/usr/bin/env bash

function test_assert_same() {
  assert_same 1 1
}

function test_assert_failing() {
  assert_same 1 2
  assert_same 3 4
}

function test_assert_todo_and_skip() {
  todo "foo"
  skip "bar"
}

function test_assert_skip_and_todo() {
  skip "baz"
  todo "yei"
}
