#!/bin/bash

function set_up() {
  ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
  source "$ROOT_DIR/example/custom_functions.sh"
}

function test_say_hi_Alice() {
  assert_equals "Hi, Alice!" "$(say_hi "Alice")"
}

function test_say_hi_Bob() {
  assert_equals "Hi, Bob!" "$(say_hi "Bob")"
}
