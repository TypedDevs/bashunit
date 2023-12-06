#!/bin/bash

function set_up_before_script() {
  ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
  source "$ROOT_DIR/example/custom-functions.sh"
}

function test_say_hi() {
  assert_equals "Hi, Juan!" "$(say_hi "Juan")"
}
