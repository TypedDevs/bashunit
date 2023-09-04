#!/bin/bash

source "$(dirname "$0")/assert.sh"

function test_successful_assert() {
  assert "✔️  Passed: Successful assert" "$(assert "1" "1")"
}

function test_unsuccessful_assert() {
  assert "❌  Unsuccessful assert failed:
 Expected '1'
 but got  '2'" "$(assert "1" "2")"
}