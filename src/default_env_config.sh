#!/bin/bash

# shellcheck disable=SC2034
_DEFAULT_PARALLEL_RUN=false
_DEFAULT_SHOW_HEADER=true
_DEFAULT_HEADER_ASCII_ART=false
_DEFAULT_SIMPLE_OUTPUT=false
_DEFAULT_STOP_ON_FAILURE=false
_DEFAULT_SHOW_EXECUTION_TIME=true
_DEFAULT_DEFAULT_PATH=
_DEFAULT_LOG_JUNIT=
_DEFAULT_REPORT_HTML=
_DEFAULT_BASHUNIT_LOAD_FILE=
_DEFAULT_TERMINAL_WIDTH=100

function find_terminal_width() {
  local cols=""

  if [[ -z "$cols" ]] && command -v stty > /dev/null; then
    cols=$(tput cols 2>/dev/null)
  fi
  if [[ -n "$TERM" ]] && command -v tput > /dev/null; then
    cols=$(stty size 2>/dev/null | cut -d' ' -f2)
  fi

  if [ -z "$cols" ] || [ "$cols" -eq 0 ]; then
      cols="$_DEFAULT_TERMINAL_WIDTH"
  fi

  echo "$cols"
}

TERMINAL_WIDTH="$(find_terminal_width)"
FAILURES_OUTPUT_PATH=$(mktemp)
CAT="$(which cat)"
