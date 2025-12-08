#!/usr/bin/env bash

# shellcheck disable=SC2034

# Load .env file (skip if --preserve-env is used to keep shell environment intact)
if [[ "${BASHUNIT_PRESERVE_ENV:-false}" != "true" ]]; then
  set -o allexport
  # shellcheck source=/dev/null
  [[ -f ".env" ]] && source .env
  set +o allexport
fi

_BASHUNIT_DEFAULT_DEFAULT_PATH="tests"
_BASHUNIT_DEFAULT_BOOTSTRAP="tests/bootstrap.sh"
_BASHUNIT_DEFAULT_DEV_LOG=""
_BASHUNIT_DEFAULT_LOG_JUNIT=""
_BASHUNIT_DEFAULT_REPORT_HTML=""

: "${BASHUNIT_DEFAULT_PATH:=${DEFAULT_PATH:=$_BASHUNIT_DEFAULT_DEFAULT_PATH}}"
: "${BASHUNIT_DEV_LOG:=${DEV_LOG:=$_BASHUNIT_DEFAULT_DEV_LOG}}"
: "${BASHUNIT_BOOTSTRAP:=${BOOTSTRAP:=$_BASHUNIT_DEFAULT_BOOTSTRAP}}"
: "${BASHUNIT_BOOTSTRAP_ARGS:=${BOOTSTRAP_ARGS:=}}"
: "${BASHUNIT_LOG_JUNIT:=${LOG_JUNIT:=$_BASHUNIT_DEFAULT_LOG_JUNIT}}"
: "${BASHUNIT_REPORT_HTML:=${REPORT_HTML:=$_BASHUNIT_DEFAULT_REPORT_HTML}}"

# Booleans
_BASHUNIT_DEFAULT_PARALLEL_RUN="false"
_BASHUNIT_DEFAULT_SHOW_HEADER="true"
_BASHUNIT_DEFAULT_HEADER_ASCII_ART="false"
_BASHUNIT_DEFAULT_SIMPLE_OUTPUT="false"
_BASHUNIT_DEFAULT_STOP_ON_FAILURE="false"
_BASHUNIT_DEFAULT_SHOW_EXECUTION_TIME="true"
_BASHUNIT_DEFAULT_VERBOSE="false"
_BASHUNIT_DEFAULT_BENCH_MODE="false"
_BASHUNIT_DEFAULT_NO_OUTPUT="false"
_BASHUNIT_DEFAULT_INTERNAL_LOG="false"
_BASHUNIT_DEFAULT_SHOW_SKIPPED="false"
_BASHUNIT_DEFAULT_SHOW_INCOMPLETE="false"
_BASHUNIT_DEFAULT_STRICT_MODE="false"
_BASHUNIT_DEFAULT_STOP_ON_ASSERTION_FAILURE="true"
_BASHUNIT_DEFAULT_PRESERVE_ENV="false"
_BASHUNIT_DEFAULT_LOGIN_SHELL="false"

: "${BASHUNIT_PARALLEL_RUN:=${PARALLEL_RUN:=$_BASHUNIT_DEFAULT_PARALLEL_RUN}}"
: "${BASHUNIT_SHOW_HEADER:=${SHOW_HEADER:=$_BASHUNIT_DEFAULT_SHOW_HEADER}}"
: "${BASHUNIT_HEADER_ASCII_ART:=${HEADER_ASCII_ART:=$_BASHUNIT_DEFAULT_HEADER_ASCII_ART}}"
: "${BASHUNIT_SIMPLE_OUTPUT:=${SIMPLE_OUTPUT:=$_BASHUNIT_DEFAULT_SIMPLE_OUTPUT}}"
: "${BASHUNIT_STOP_ON_FAILURE:=${STOP_ON_FAILURE:=$_BASHUNIT_DEFAULT_STOP_ON_FAILURE}}"
: "${BASHUNIT_SHOW_EXECUTION_TIME:=${SHOW_EXECUTION_TIME:=$_BASHUNIT_DEFAULT_SHOW_EXECUTION_TIME}}"
: "${BASHUNIT_VERBOSE:=${VERBOSE:=$_BASHUNIT_DEFAULT_VERBOSE}}"
: "${BASHUNIT_BENCH_MODE:=${BENCH_MODE:=$_BASHUNIT_DEFAULT_BENCH_MODE}}"
: "${BASHUNIT_NO_OUTPUT:=${NO_OUTPUT:=$_BASHUNIT_DEFAULT_NO_OUTPUT}}"
: "${BASHUNIT_INTERNAL_LOG:=${INTERNAL_LOG:=$_BASHUNIT_DEFAULT_INTERNAL_LOG}}"
: "${BASHUNIT_SHOW_SKIPPED:=${SHOW_SKIPPED:=$_BASHUNIT_DEFAULT_SHOW_SKIPPED}}"
: "${BASHUNIT_SHOW_INCOMPLETE:=${SHOW_INCOMPLETE:=$_BASHUNIT_DEFAULT_SHOW_INCOMPLETE}}"
: "${BASHUNIT_STRICT_MODE:=${STRICT_MODE:=$_BASHUNIT_DEFAULT_STRICT_MODE}}"
: "${BASHUNIT_STOP_ON_ASSERTION_FAILURE:=${STOP_ON_ASSERTION_FAILURE:=$_BASHUNIT_DEFAULT_STOP_ON_ASSERTION_FAILURE}}"
: "${BASHUNIT_PRESERVE_ENV:=${PRESERVE_ENV:=$_BASHUNIT_DEFAULT_PRESERVE_ENV}}"
: "${BASHUNIT_LOGIN_SHELL:=${LOGIN_SHELL:=$_BASHUNIT_DEFAULT_LOGIN_SHELL}}"

function bashunit::env::is_parallel_run_enabled() {
  [[ "$BASHUNIT_PARALLEL_RUN" == "true" ]]
}

function bashunit::env::is_show_header_enabled() {
  [[ "$BASHUNIT_SHOW_HEADER" == "true" ]]
}

function bashunit::env::is_header_ascii_art_enabled() {
  [[ "$BASHUNIT_HEADER_ASCII_ART" == "true" ]]
}

function bashunit::env::is_simple_output_enabled() {
  [[ "$BASHUNIT_SIMPLE_OUTPUT" == "true" ]]
}

function bashunit::env::is_stop_on_failure_enabled() {
  [[ "$BASHUNIT_STOP_ON_FAILURE" == "true" ]]
}

function bashunit::env::is_show_execution_time_enabled() {
  [[ "$BASHUNIT_SHOW_EXECUTION_TIME" == "true" ]]
}

function bashunit::env::is_dev_mode_enabled() {
  [[ -n "$BASHUNIT_DEV_LOG" ]]
}

function bashunit::env::is_internal_log_enabled() {
  [[ "$BASHUNIT_INTERNAL_LOG" == "true" ]]
}

function bashunit::env::is_verbose_enabled() {
  [[ "$BASHUNIT_VERBOSE" == "true" ]]
}

function bashunit::env::is_bench_mode_enabled() {
  [[ "$BASHUNIT_BENCH_MODE" == "true" ]]
}

function bashunit::env::is_no_output_enabled() {
  [[ "$BASHUNIT_NO_OUTPUT" == "true" ]]
}

function bashunit::env::is_show_skipped_enabled() {
  [[ "$BASHUNIT_SHOW_SKIPPED" == "true" ]]
}

function bashunit::env::is_show_incomplete_enabled() {
  [[ "$BASHUNIT_SHOW_INCOMPLETE" == "true" ]]
}

function bashunit::env::is_strict_mode_enabled() {
  [[ "$BASHUNIT_STRICT_MODE" == "true" ]]
}

function bashunit::env::is_stop_on_assertion_failure_enabled() {
  [[ "$BASHUNIT_STOP_ON_ASSERTION_FAILURE" == "true" ]]
}

function bashunit::env::is_preserve_env_enabled() {
  [[ "$BASHUNIT_PRESERVE_ENV" == "true" ]]
}

function bashunit::env::is_login_shell_enabled() {
  [[ "$BASHUNIT_LOGIN_SHELL" == "true" ]]
}

function bashunit::env::active_internet_connection() {
  if [[ "${BASHUNIT_NO_NETWORK:-}" == "true" ]]; then
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -sfI https://github.com >/dev/null 2>&1 && return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -q --spider https://github.com && return 0
  fi

  if ping -c 1 -W 3 google.com &> /dev/null; then
    return 0
  fi

  return 1
}

function bashunit::env::find_terminal_width() {
  local cols=""

  if [[ -z "$cols" ]] && command -v tput > /dev/null; then
    cols=$(tput cols 2>/dev/null)
  fi

  if [[ -z "$cols" ]] && command -v stty > /dev/null; then
    cols=$(stty size 2>/dev/null | cut -d' ' -f2)
  fi

  # Directly echo the value with fallback
  echo "${cols:-100}"
}

function bashunit::env::print_verbose() {
  bashunit::internal_log "Printing verbose environment variables"
  local keys=(
    "BASHUNIT_DEFAULT_PATH"
    "BASHUNIT_DEV_LOG"
    "BASHUNIT_BOOTSTRAP"
    "BASHUNIT_BOOTSTRAP_ARGS"
    "BASHUNIT_LOG_JUNIT"
    "BASHUNIT_REPORT_HTML"
    "BASHUNIT_PARALLEL_RUN"
    "BASHUNIT_SHOW_HEADER"
    "BASHUNIT_HEADER_ASCII_ART"
    "BASHUNIT_SIMPLE_OUTPUT"
    "BASHUNIT_STOP_ON_FAILURE"
    "BASHUNIT_SHOW_EXECUTION_TIME"
    "BASHUNIT_VERBOSE"
    "BASHUNIT_STRICT_MODE"
    "BASHUNIT_STOP_ON_ASSERTION_FAILURE"
    "BASHUNIT_PRESERVE_ENV"
    "BASHUNIT_LOGIN_SHELL"
  )

  local max_length=0

  for key in "${keys[@]}"; do
    if (( ${#key} > max_length )); then
      max_length=${#key}
    fi
  done

  for key in "${keys[@]}"; do
    bashunit::internal_log "$key=${!key}"
    printf "%s:%*s%s\n" "$key" $((max_length - ${#key} + 1)) "" "${!key}"
  done
}

EXIT_CODE_STOP_ON_FAILURE=4
# Use a unique directory per run to avoid conflicts when bashunit is invoked
# recursively or multiple instances are executed in parallel.
TEMP_DIR_PARALLEL_TEST_SUITE="${TMPDIR:-/tmp}/bashunit/parallel/${_BASHUNIT_OS:-Unknown}/$(bashunit::random_str 8)"
TEMP_FILE_PARALLEL_STOP_ON_FAILURE="$TEMP_DIR_PARALLEL_TEST_SUITE/.stop-on-failure"
TERMINAL_WIDTH="$(bashunit::env::find_terminal_width)"
FAILURES_OUTPUT_PATH=$(mktemp)
SKIPPED_OUTPUT_PATH=$(mktemp)
INCOMPLETE_OUTPUT_PATH=$(mktemp)
CAT="$(command -v cat)"

# Initialize temp directory once at startup for performance
BASHUNIT_TEMP_DIR="${TMPDIR:-/tmp}/bashunit/tmp"
mkdir -p "$BASHUNIT_TEMP_DIR" 2>/dev/null || true

if bashunit::env::is_dev_mode_enabled; then
  bashunit::internal_log "info" "Dev log enabled" "file:$BASHUNIT_DEV_LOG"
fi
