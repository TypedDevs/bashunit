#!/bin/bash

function set_up() {
  ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
  SCRIPT="$ROOT_DIR/example/script-logic.sh"
}

function test_script() {
  assert_equals "expected 123" "$($SCRIPT "123")"
}
