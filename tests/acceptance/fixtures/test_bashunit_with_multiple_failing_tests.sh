#!/bin/bash

function test_assert_same() {
  assert_same 1 1
}

function test_assert_failing() {
  assert_same 1 2
  assert_same 3 4
}
