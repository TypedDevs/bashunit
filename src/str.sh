#!/bin/bash

function str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-(($TERMINAL_WIDTH))}"
  local padding=$((width_padding - ${#left_text}))

  printf "%s%*s" "$left_text" "$padding" "$right_word"
}
