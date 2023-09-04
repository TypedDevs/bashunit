#!/bin/bash

source "$ROOT_DIR/tools/bashunit/src/assert.sh"

readonly SCRIPT="$ROOT_DIR/git-hooks/prepare-commit-msg.sh"

function test_your_logic() {
  assertEquals "expected 123" "$("$SCRIPT" "123")"
}
