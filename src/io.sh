#!/usr/bin/env bash

##
# Clear the terminal screen and move the cursor to the home position.
# Uses `tput clear` when available (queries terminfo for the right sequence)
# and falls back to the ANSI sequence \033[2J\033[H otherwise.
##
function bashunit::io::clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear
  else
    printf '\033[2J\033[H'
  fi
}

function bashunit::io::download_to() {
  local url="$1"
  local output="$2"
  if bashunit::dependencies::has_curl; then
    curl -L -J -o "$output" "$url" 2>/dev/null
  elif bashunit::dependencies::has_wget; then
    wget -q -O "$output" "$url" 2>/dev/null
  else
    return 1
  fi
}
