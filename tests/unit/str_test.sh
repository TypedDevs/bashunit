#!/bin/bash

# shellcheck disable=SC2155

function test_rpad_default_width_padding() {
  export TERMINAL_WIDTH=50

  local actual=$(str::rpad "input" "right-text")

  assert_same "input                    right-text" "$actual"
}

function test_rpad_custom_width_padding() {
  local actual=$(str::rpad "input" "right-text" 30)

  assert_same "input     right-text" "$actual"
}
