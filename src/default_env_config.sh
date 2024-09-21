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
_DEFAULT_TERMINAL_WIDTH=150

CAT="$(which cat)"

function find_terminal_width() {
  if [[ -n "$TERM" && $(command -v tput) ]]; then
      _cols=$(tput cols 2>/dev/null) || _cols=""

      # If tput fails, fallback to stty if available
      if [[ -z "$_cols" ]] && command -v stty > /dev/null; then
          _cols=$(stty size | cut -d' ' -f2)
      fi
  else
      # Fallback to stty if TERM is not set and stty is available
      if command -v stty > /dev/null; then
          _cols=$(stty size | cut -d' ' -f2)
      fi
  fi

  if [[ -z "$_cols" ]]; then
      _cols=$_DEFAULT_TERMINAL_WIDTH
  fi

  echo "$_cols"
}

TERMINAL_WIDTH="$(find_terminal_width)"
