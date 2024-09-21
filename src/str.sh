#!/bin/bash

function str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-(($TERMINAL_WIDTH - 5))}"

  if [[ -z "$left_text" ]]; then
    local padding=$((width_padding - ${#right_word}))
    printf "%*s" "$padding" "$right_word"
    return
  fi

  local total_length=$(( ${#left_text} + ${#right_word} ))
  local padding=$((width_padding - total_length))

  printf "%s%*s" "$left_text" "$padding" "$right_word"
}
