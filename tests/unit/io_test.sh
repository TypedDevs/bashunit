#!/usr/bin/env bash

function test_clear_screen_uses_tput_when_available() {
  bashunit::mock tput <<<"CLEARED"

  local output
  output=$(bashunit::io::clear_screen)

  assert_contains "CLEARED" "$output"
}

function test_clear_screen_emits_non_empty_output() {
  local output
  output=$(bashunit::io::clear_screen)

  assert_not_empty "$output"
}
