#!/usr/bin/env bash

function progress::init() {
  export PROGRESS_TOTAL=$1

  if parallel::is_enabled || [[ ! -t 1 ]] || ! env::is_progress_enabled; then
    _PROGRESS_ENABLED=false
  else
    _PROGRESS_ENABLED=true
    progress::blank_line
  fi
}

function progress::render() {
  local current=$1
  local total=$2

  if [[ "$_PROGRESS_ENABLED" != true ]]; then
    return
  fi

  if [[ ! -t 1 ]]; then
    return
  fi

  if [[ -z "$total" || "$total" -eq 0 ]]; then
    return
  fi

  local width=$((TERMINAL_WIDTH - 20))
  (( width < 10 )) && width=10

  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar

  bar=""
  for ((i=0; i<filled; i++)); do
    bar+="#"
  done
  for ((i=0; i<empty; i++)); do
    bar+="-"
  done

  local line
  line=$(printf '[%s] %d/%d' "$bar" "$current" "$total")

  if command -v tput > /dev/null; then
    tput sc
    tput cup $(( $(tput lines) - 1 )) 0
    printf '%-*s' "$TERMINAL_WIDTH" "$line"
    tput rc
  else
    printf '\r%-*s' "$TERMINAL_WIDTH" "$line"
  fi
}

function progress::finish() {
  if [[ "$_PROGRESS_ENABLED" != true ]]; then
    return
  fi

  if command -v tput > /dev/null; then
    tput sc
    tput cup $(( $(tput lines) - 1 )) 0
    printf '%*s\n' "$TERMINAL_WIDTH" ''
    tput rc
  else
    printf '\n'
  fi
}

# Print an empty line, ensuring any residual characters are cleared by
# filling the entire terminal width with spaces before emitting a newline.
function progress::blank_line() {
  if [[ -t 1 ]] && command -v tput > /dev/null; then
    printf '%*s\n' "$TERMINAL_WIDTH" ''
  else
    printf '\n'
  fi
}
