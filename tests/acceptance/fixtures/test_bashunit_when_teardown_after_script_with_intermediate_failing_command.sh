#!/usr/bin/env bash

function test_dummy() {
  assert_same "foo" "foo"
}

function tear_down_after_script() {
  false
  true
}
