#!/bin/bash

# shellcheck disable=SC2155

function test_rpad_default_width_padding_and_empty_left_text() {
  export TERMINAL_WIDTH=30

  local actual=$(str::rpad "" "right-text")

  assert_same "                    right-text" "$actual"
}

function test_rpad_default_width_padding() {
  export TERMINAL_WIDTH=30

  local actual=$(str::rpad "input" "right-text")

  assert_same "input               right-text" "$actual"
}

function test_rpad_custom_width_padding_1_digit() {
  local actual=$(str::rpad "input" "1" 20)

  assert_same "input              1" "$actual"
}

function test_rpad_custom_width_padding_2_digit() {
  local actual=$(str::rpad "input" "10" 20)

  assert_same "input             10" "$actual"
}
function test_rpad_custom_width_padding_3_digit() {
  local actual=$(str::rpad "input" "100" 20)

  assert_same "input            100" "$actual"
}