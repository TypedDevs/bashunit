#!/bin/bash

function str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-$TERMINAL_WIDTH}"
  local padding=$((width_padding - ${#right_word}))

  # If the left text exceeds the padding, truncate it and add "..."
  if [[ ${#left_text} -gt $padding ]]; then
    left_text="${left_text:0:$((padding - 3))}..."
  fi

  printf "%-${padding}s%s" "$left_text" "$right_word"
}
