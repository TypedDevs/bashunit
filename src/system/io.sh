#!/usr/bin/env bash

##
# Clear the terminal screen and move the cursor to the home position.
# Uses `tput clear` when available (queries terminfo for the right sequence)
# and falls back to the ANSI sequence \033[2J\033[H otherwise.
##
##
# Echoes the byte size of $1, or "unknown" when it cannot be read.
#
# `wc -c` is a fork, which is why this is not on any hot path: it exists for
# the failure message in discovery.sh, where one fork buys the difference
# between "the file was truncated" and "its last command returned non-zero"
# (#1137).
##
function bashunit::io::file_size() {
  local bytes
  bytes=$(wc -c <"$1" 2>/dev/null | tr -d ' ') || bytes=""
  if [ -z "$bytes" ]; then
    bytes="unknown"
  fi
  printf '%s' "$bytes"
}

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
