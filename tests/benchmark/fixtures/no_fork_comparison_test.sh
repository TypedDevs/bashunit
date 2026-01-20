#!/usr/bin/env bash

# Simple test functions for benchmarking no-fork vs normal mode
# These tests do minimal work to measure the overhead difference

function test_simple_assertion_1() {
  assert_equals "foo" "foo"
}

function test_simple_assertion_2() {
  assert_equals "bar" "bar"
}

function test_simple_assertion_3() {
  assert_equals "baz" "baz"
}

function test_simple_assertion_4() {
  assert_contains "world" "hello world"
}

function test_simple_assertion_5() {
  assert_not_empty "something"
}

function test_simple_assertion_6() {
  assert_empty ""
}

function test_simple_assertion_7() {
  assert_equals 42 42
}

function test_simple_assertion_8() {
  assert_equals "test" "test"
}

function test_simple_assertion_9() {
  assert_not_equals "a" "b"
}

function test_simple_assertion_10() {
  assert_equals "done" "done"
}
