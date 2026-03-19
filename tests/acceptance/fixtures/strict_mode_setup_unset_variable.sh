#!/usr/bin/env bash
# shellcheck disable=SC2034

function set_up() {
  local result="prefix_${UNDEFINED_VAR}_suffix"
}

function test_dummy() {
  assert_same "foo" "foo"
}
