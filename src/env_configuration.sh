#!/bin/bash

set -o allexport
# shellcheck source=/dev/null
[[ -f ".env" ]] && source .env set
set +o allexport

: "${BASHUNIT_DEFAULT_PATH:=${DEFAULT_PATH:=$_DEFAULT_DEFAULT_PATH}}"
: "${BASHUNIT_LOG_JUNIT:=${LOG_JUNIT:=$_DEFAULT_LOG_JUNIT}}"
: "${BASHUNIT_REPORT_HTML:=${REPORT_HTML:=$_DEFAULT_REPORT_HTML}}"
: "${BASHUNIT_LOAD_FILE:=${LOAD_FILE:=$_DEFAULT_BASHUNIT_LOAD_FILE}}"

# Booleans
: "${BASHUNIT_PARALLEL_RUN:=${PARALLEL_RUN:=$_DEFAULT_PARALLEL_RUN}}"
: "${BASHUNIT_SHOW_HEADER:=${SHOW_HEADER:=$_DEFAULT_SHOW_HEADER}}"
: "${BASHUNIT_HEADER_ASCII_ART:=${HEADER_ASCII_ART:=$_DEFAULT_HEADER_ASCII_ART}}"
: "${BASHUNIT_SIMPLE_OUTPUT:=${SIMPLE_OUTPUT:=$_DEFAULT_SIMPLE_OUTPUT}}"
: "${BASHUNIT_STOP_ON_FAILURE:=${STOP_ON_FAILURE:=$_DEFAULT_STOP_ON_FAILURE}}"
: "${BASHUNIT_SHOW_EXECUTION_TIME:=${SHOW_EXECUTION_TIME:=$_DEFAULT_SHOW_EXECUTION_TIME}}"

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
