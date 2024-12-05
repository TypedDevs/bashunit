#!/bin/bash

function test_assert_same() {
  assert_same 1 1
}

function test_assert_failing() {
  assert_same 1 0
  assert_same 2 3
  assert_same 4 5
}
