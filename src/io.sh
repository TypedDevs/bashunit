#!/usr/bin/env bash

##
# Clear the terminal screen and move the cursor to the home position.
# Uses `tput clear` when available (queries terminfo for the right sequence)
# and falls back to the ANSI sequence \033[2J\033[H otherwise.
##
function bashunit::io::clear_screen() {
  if bashunit::dependencies::has_tput; then
    local out
    out=$(tput clear 2>/dev/null)
    if [ -n "$out" ]; then
      printf '%s' "$out"
      return
    fi
  fi
  printf '\033[2J\033[H'
}

function bashunit::io::download_to() {
  local url="$1"
  local output="$2"
  if bashunit::dependencies::has_curl; then
    curl -fsSL -o "$output" "$url"
  elif bashunit::dependencies::has_wget; then
    wget -q -O "$output" "$url"
  else
    echo "no curl or wget available" >&2
    return 1
  fi
}
