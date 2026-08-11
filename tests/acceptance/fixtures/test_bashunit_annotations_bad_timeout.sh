#!/usr/bin/env bash

# @timeout abc
function test_malformed_timeout() {
  assert_same "ok" "ok"
}
