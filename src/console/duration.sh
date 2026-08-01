#!/usr/bin/env bash

# Formatting a millisecond duration for display.

##
# Writes a human-readable duration (Xm Ys / X.XXs / Xms) into
# _BASHUNIT_CONSOLE_DURATION_OUT. Fork-free, so per-test render paths can format
# a duration without a $(...) capture.
# Arguments: $1 - duration in milliseconds
##
function bashunit::console_results::format_duration_to_slot() {
  local duration_ms="$1"

  if [ "$duration_ms" -ge 60000 ]; then
    local time_in_seconds=$((duration_ms / 1000))
    local minutes=$((time_in_seconds / 60))
    local seconds=$((time_in_seconds % 60))
    _BASHUNIT_CONSOLE_DURATION_OUT="${minutes}m ${seconds}s"
  elif [ "$duration_ms" -ge 1000 ]; then
    local integer_part=$((duration_ms / 1000))
    local decimal_part=$(((duration_ms % 1000) / 10))
    # Pad the hundredths by hand: printf would cost a fork on this hot path.
    if [ "$decimal_part" -lt 10 ]; then
      decimal_part="0${decimal_part}"
    fi
    _BASHUNIT_CONSOLE_DURATION_OUT="${integer_part}.${decimal_part}s"
  else
    _BASHUNIT_CONSOLE_DURATION_OUT="${duration_ms}ms"
  fi
}


function bashunit::console_results::format_duration() {
  bashunit::console_results::format_duration_to_slot "$1"
  echo "$_BASHUNIT_CONSOLE_DURATION_OUT"
}

