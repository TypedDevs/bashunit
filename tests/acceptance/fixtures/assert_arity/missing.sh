#!/usr/bin/env bash

function test_wrong_arg_count() {
  assert_same "only-one"
  assert_same "later assertion" "later assertion"
}
