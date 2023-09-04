#!/bin/bash

source "$ROOT_DIR/src/assert.sh"

function test_successful_assertEquals() {
  assertEquals "✔️  Passed: Successful assertEquals" "$(assertEquals "1" "1")"
}

function test_unsuccessful_assertEquals() {
  assertEquals "❌  Unsuccessful assertEquals failed:
 Expected '1'
 but got  '2'" "$(assertEquals "1" "2")"
}