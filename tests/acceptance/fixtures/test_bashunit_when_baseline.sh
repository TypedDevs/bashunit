#!/usr/bin/env bash

function test_passes() {
  assert_same 1 1
}

function test_fails() {
  assert_same 1 2
}

function test_also_fails() {
  assert_same "expected" "actual"
}
