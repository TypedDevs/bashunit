#!/usr/bin/env bash

# Strip ANSI escape codes and control characters
function bashunit::str::strip_ansi() {
  local input="$1"
  echo -e "$input" | sed -E 's/\x1B\[[0-9;]*[mK]//g; s/[[:cntrl:]]//g'
}

function bashunit::str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-$TERMINAL_WIDTH}"
  # Subtract 1 more to account for the extra space
  local padding=$((width_padding - ${#right_word} - 1))
  if (( padding < 0 )); then
    padding=0
  fi

  # Remove ANSI escape sequences (non-visible characters) for length calculation
  # shellcheck disable=SC2155
  local clean_left_text=$(bashunit::str::strip_ansi "$left_text")

  local is_truncated=false
  # If the visible left text exceeds the padding, truncate it and add "..."
  if [[ ${#clean_left_text} -gt $padding ]]; then
    local truncation_length=$((padding < 3 ? 0 : padding - 3))
    clean_left_text="${clean_left_text:0:$truncation_length}"
    is_truncated=true
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
        result_left_text="$result_left_text${left_text:$j:1}"
        ((j++))
      done
      result_left_text="$result_left_text${left_text:$j:1}"  # Append the final 'm'
      ((j++))
    elif [[ "$char" == "$original_char" ]]; then
      # Match the actual character
      result_left_text="$result_left_text$char"
      ((i++))
      ((j++))
    else
      ((j++))
    fi
  done

  local remaining_space
  if $is_truncated ; then
    result_left_text="$result_left_text..."
    # 1: due to a blank space
    # 3: due to the appended ...
    remaining_space=$((width_padding - ${#clean_left_text} - ${#right_word} - 1 - 3))
  else
    # Copy any remaining characters after the truncation point
    result_left_text="$result_left_text${left_text:$j}"
    remaining_space=$((width_padding - ${#clean_left_text} - ${#right_word} - 1))
  fi

  # Ensure the right word is placed exactly at the far right of the screen
  # filling the remaining space with padding
  if [[ $remaining_space -lt 0 ]]; then
    remaining_space=0
  fi

  printf "%s%${remaining_space}s %s\n" "$result_left_text" "" "$right_word"
}
