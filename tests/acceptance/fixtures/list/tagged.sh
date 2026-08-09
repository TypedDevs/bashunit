#!/usr/bin/env bash

# @tag slow
function test_tagged_slow() {
  assert_true true
}

# @tag fast
function test_tagged_fast() {
  assert_true true
}
