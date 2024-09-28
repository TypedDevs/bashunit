#!/bin/bash

function str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-$TERMINAL_WIDTH}"
  local padding=$((width_padding - ${#right_word} - 1))  # Subtract 1 more to account for the extra space

  # Remove ANSI escape sequences (non-visible characters) for length calculation
  # shellcheck disable=SC2155
  local clean_left_text=$(echo -e "$left_text" | sed 's/\x1b\[[0-9;]*m//g')

  local truncated=false
  # If the visible left text exceeds the padding, truncate it and add "..."
  if [[ ${#clean_left_text} -gt $padding ]]; then
    local truncation_length=$((padding - 3))  # Subtract 3 for "..."
    clean_left_text="${clean_left_text:0:$truncation_length}"
    truncated=true
  fi

  # Rebuild the text with ANSI codes intact, preserving the truncation
  local result_left_text=""
  local i=0
  local j=0
  while [[ $i -lt ${#clean_left_text} && $j -lt ${#left_text} ]]; do
    local char="${clean_left_text:$i:1}"
    local original_char="${left_text:$j:1}"

    # If the current character is part of an ANSI sequence, skip it and copy it
    if [[ "$original_char" == $'\x1b' ]]; then
      while [[ "${left_text:$j:1}" != "m" && $j -lt ${#left_text} ]]; do
        result_left_text+="${left_text:$j:1}"
        ((j++))
      done
      result_left_text+="${left_text:$j:1}"  # Append the final 'm'
      ((j++))
    elif [[ "$char" == "$original_char" ]]; then
      # Match the actual character
      result_left_text+="$char"
      ((i++))
      ((j++))
    else
      ((j++))
    fi
  done

  if $truncated; then
    result_left_text+="..."
  else
    # Copy any remaining characters after the truncation point
    result_left_text+="${left_text:$j}"
  fi

  printf "%-${padding}s %s" "$result_left_text" "$right_word"
}
