#!/bin/bash

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
SCRIPT="$ROOT_DIR/example/logic.sh"

function test_your_logic() {
  assertEquals "expected 123" "$($SCRIPT "123")"
}
