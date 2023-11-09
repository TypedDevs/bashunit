#!/bin/bash

function test_assert_equals() {
  assert_equals 1 1
}

function test_assert_contains() {
  assert_contains "foo" "foobar"
  assert_contains "bar" "foobar"
}
