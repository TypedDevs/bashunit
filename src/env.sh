#!/bin/bash

# shellcheck disable=SC2034

set -o allexport
# shellcheck source=/dev/null
[[ -f ".env" ]] && source .env set
set +o allexport

_DEFAULT_DEFAULT_PATH="tests"
_DEFAULT_DEV_LOG="dev.log"
_DEFAULT_LOAD_FILE="tests/bootstrap.sh"
_DEFAULT_LOG_JUNIT=""
_DEFAULT_REPORT_HTML=""

: "${BASHUNIT_DEFAULT_PATH:=${DEFAULT_PATH:=$_DEFAULT_DEFAULT_PATH}}"
: "${BASHUNIT_DEV_LOG:=${DEV_LOG:=$_DEFAULT_DEV_LOG}}"
: "${BASHUNIT_LOAD_FILE:=${LOAD_FILE:=$_DEFAULT_LOAD_FILE}}"
: "${BASHUNIT_LOG_JUNIT:=${LOG_JUNIT:=$_DEFAULT_LOG_JUNIT}}"
: "${BASHUNIT_REPORT_HTML:=${REPORT_HTML:=$_DEFAULT_REPORT_HTML}}"

# Booleans
_DEFAULT_PARALLEL_RUN="false"
_DEFAULT_SHOW_HEADER="true"
_DEFAULT_HEADER_ASCII_ART="false"
_DEFAULT_SIMPLE_OUTPUT="false"
_DEFAULT_STOP_ON_FAILURE="false"
_DEFAULT_SHOW_EXECUTION_TIME="true"
_DEFAULT_DEV_MODE="false"
_DEFAULT_VERBOSE="false"

: "${BASHUNIT_PARALLEL_RUN:=${PARALLEL_RUN:=$_DEFAULT_PARALLEL_RUN}}"
: "${BASHUNIT_SHOW_HEADER:=${SHOW_HEADER:=$_DEFAULT_SHOW_HEADER}}"
: "${BASHUNIT_HEADER_ASCII_ART:=${HEADER_ASCII_ART:=$_DEFAULT_HEADER_ASCII_ART}}"
: "${BASHUNIT_SIMPLE_OUTPUT:=${SIMPLE_OUTPUT:=$_DEFAULT_SIMPLE_OUTPUT}}"
: "${BASHUNIT_STOP_ON_FAILURE:=${STOP_ON_FAILURE:=$_DEFAULT_STOP_ON_FAILURE}}"
: "${BASHUNIT_SHOW_EXECUTION_TIME:=${SHOW_EXECUTION_TIME:=$_DEFAULT_SHOW_EXECUTION_TIME}}"
: "${BASHUNIT_DEV_MODE:=${DEV_MODE:=$_DEFAULT_DEV_MODE}}"
: "${BASHUNIT_VERBOSE:=${VERBOSE:=$_DEFAULT_VERBOSE}}"

function env::is_parallel_run_enabled() {
  [[ "$BASHUNIT_PARALLEL_RUN" == "true" ]]
}

function env::is_show_header_enabled() {
  [[ "$BASHUNIT_SHOW_HEADER" == "true" ]]
}

function env::is_header_ascii_art_enabled() {
  [[ "$BASHUNIT_HEADER_ASCII_ART" == "true" ]]
}

function env::is_simple_output_enabled() {
  [[ "$BASHUNIT_SIMPLE_OUTPUT" == "true" ]]
}

function env::is_stop_on_failure_enabled() {
  [[ "$BASHUNIT_STOP_ON_FAILURE" == "true" ]]
}

function env::is_show_execution_time_enabled() {
  [[ "$BASHUNIT_SHOW_EXECUTION_TIME" == "true" ]]
}

function env::is_dev_mode_enabled() {
  [[ "$BASHUNIT_DEV_MODE" == "true" ]]
}

function env::is_verbose_enabled() {
  [[ "$BASHUNIT_VERBOSE" == "true" ]]
}

function env::find_terminal_width() {
  local cols=""

  if [[ -z "$cols" ]] && command -v stty > /dev/null; then
    cols=$(tput cols 2>/dev/null)
  fi
  if [[ -n "$TERM" ]] && command -v tput > /dev/null; then
    cols=$(stty size 2>/dev/null | cut -d' ' -f2)
  fi

  # Directly echo the value with fallback
  echo "${cols:-100}"
}

function env::print_verbose() {
  local keys=(
    "BASHUNIT_DEFAULT_PATH"
    "BASHUNIT_DEV_LOG"
    "BASHUNIT_LOAD_FILE"
    "BASHUNIT_LOG_JUNIT"
    "BASHUNIT_REPORT_HTML"
    "BASHUNIT_PARALLEL_RUN"
    "BASHUNIT_SHOW_HEADER"
    "BASHUNIT_HEADER_ASCII_ART"
    "BASHUNIT_SIMPLE_OUTPUT"
    "BASHUNIT_STOP_ON_FAILURE"
    "BASHUNIT_SHOW_EXECUTION_TIME"
    "BASHUNIT_DEV_MODE"
    "BASHUNIT_VERBOSE"
  )

  local max_length=0

  for key in "${keys[@]}"; do
    if (( ${#key} > max_length )); then
      max_length=${#key}
    fi
  done

  for key in "${keys[@]}"; do
    printf "%s:%*s%s\n" "$key" $((max_length - ${#key} + 1)) "" "${!key}"
  done
}

EXIT_CODE_STOP_ON_FAILURE=4
TEMP_DIR_PARALLEL_TEST_SUITE="/tmp/bashunit/parallel/${_OS:-Unknown}"
TEMP_FILE_PARALLEL_STOP_ON_FAILURE="$TEMP_DIR_PARALLEL_TEST_SUITE/.stop-on-failure"
TERMINAL_WIDTH="$(env::find_terminal_width)"
FAILURES_OUTPUT_PATH=$(mktemp)
CAT="$(which cat)"
