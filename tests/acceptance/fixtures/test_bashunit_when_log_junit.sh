#!/bin/bash

function test_a_success() {
  assert_equals 1 1
}

function test_b_error() {
  assert_equals 1 1
  assert_equals 1 2 # error
  assert_equals 2 2
}

function test_c_not_executed() {
  assert_equals 2 2
}
