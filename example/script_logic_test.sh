#!/usr/bin/env bash

function set_up() {
  ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
  SCRIPT="$ROOT_DIR/example/script_logic.sh"
}

function test_script_123() {
  assert_same "expected 123" "$($SCRIPT "123")"
}

function test_script_456() {
  assert_same "expected 456" "$($SCRIPT "456")"
}
