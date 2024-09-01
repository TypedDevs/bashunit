#!/bin/bash

function test_a_success() {
  assert_same 1 1
}
function test_b_error() {
  assert_same 1 1
  assert_same 1 2 # error
  assert_same 2 2
}

function test_c_not_executed() {
  assert_same 2 2
}
