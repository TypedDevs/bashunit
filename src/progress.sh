#!/usr/bin/env bash

# Check if progress bar is enabled and not in parallel mode
function progress::enabled() {
  env::is_progress_bar_enabled && ! parallel::is_enabled
}

# Initialize progress tracking variables and optionally render the first bar
function progress::init() {
  export PROGRESS_BAR_TOTAL=$1
  export PROGRESS_BAR_CURRENT=0

  if env::is_progress_bar_enabled && parallel::is_enabled; then
    printf "%sWarning: Progress bar is not supported in parallel mode.%s\n" \
      "${_COLOR_INCOMPLETE}" "${_COLOR_DEFAULT}"
  fi

  if progress::enabled; then
    progress::render 0 "$PROGRESS_BAR_TOTAL"
  fi
}

# Render the progress bar line
function progress::render() {
  local current total width filled empty i bar line

  current=$1
  total=$2
  PROGRESS_BAR_CURRENT=$current

  if ! progress::enabled || [[ ! -t 1 ]] || [[ -z "$total" || "$total" -eq 0 ]]; then
    return
  fi

  width=$((TERMINAL_WIDTH - 20))
  [ "$width" -lt 10 ] && width=10

  filled=$(( current * width / total ))
  empty=$(( width - filled ))

  bar=''
  i=0
  while [ $i -lt $filled ]; do
    bar="${bar}#"
    i=$((i + 1))
  done
  i=0
  while [ $i -lt $empty ]; do
    bar="${bar}-"
    i=$((i + 1))
  done

  line=$(printf '[%s] %d/%d' "$bar" "$current" "$total")

  if command -v tput >/dev/null; then
    tput sc
    tput cup $(( $(tput lines) - 1 )) 0
    printf '%-*s' "$TERMINAL_WIDTH" "$line"
    tput rc
  else
    printf '\r%-*s' "$TERMINAL_WIDTH" "$line"
  fi
}

# Finish and clear the progress bar line
function progress::finish() {
  if ! progress::enabled; then
    return
  fi

  if command -v tput >/dev/null; then
    tput sc
    tput cup $(( $(tput lines) - 1 )) 0
    printf '%*s' "$TERMINAL_WIDTH" ''
    tput rc
  else
    printf '\r%-*s' "$TERMINAL_WIDTH" ''
  fi
}

# Redraw the progress bar using the current known state
function progress::refresh() {
  if progress::enabled; then
    progress::render "${PROGRESS_BAR_CURRENT:-0}" "${PROGRESS_BAR_TOTAL:-0}"
  fi
}

# Print an empty line, clearing any previous progress bar content
function progress::blank_line() {
  if [[ -t 1 ]] && command -v tput >/dev/null; then
    printf '%*s\n' "$TERMINAL_WIDTH" ''
  else
    printf '\n'
  fi
}
