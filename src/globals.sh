#!/usr/bin/env bash
set -euo pipefail

# This file provides a set of global functions to developers.

function bashunit::current_dir() {
  dirname "${BASH_SOURCE[1]}"
}

function bashunit::current_filename() {
  basename "${BASH_SOURCE[1]}"
}

function bashunit::caller_filename() {
  dirname "${BASH_SOURCE[2]}"
}

function bashunit::caller_line() {
  echo "${BASH_LINENO[1]}"
}

function bashunit::current_timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

function bashunit::is_command_available() {
  command -v "$1" >/dev/null 2>&1
}

function bashunit::random_str() {
  local length=${1:-6}
  local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  local str=''
  for (( i=0; i<length; i++ )); do
    str+="${chars:RANDOM%${#chars}:1}"
  done
  echo "$str"
}

function bashunit::temp_file() {
  local prefix=${1:-bashunit}
  local test_prefix=""
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    # We're inside a test function - use test ID
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  elif [[ -n "${BASHUNIT_CURRENT_SCRIPT_ID:-}" ]]; then
    # We're at script level (e.g., in set_up_before_script) - use script ID
    test_prefix="${BASHUNIT_CURRENT_SCRIPT_ID}_"
  fi
  mktemp "$BASHUNIT_TEMP_DIR/${test_prefix}${prefix}.XXXXXXX"
}

function bashunit::temp_dir() {
  local prefix=${1:-bashunit}
  local test_prefix=""
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    # We're inside a test function - use test ID
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  elif [[ -n "${BASHUNIT_CURRENT_SCRIPT_ID:-}" ]]; then
    # We're at script level (e.g., in set_up_before_script) - use script ID
    test_prefix="${BASHUNIT_CURRENT_SCRIPT_ID}_"
  fi
  mktemp -d "$BASHUNIT_TEMP_DIR/${test_prefix}${prefix}.XXXXXXX"
}

function bashunit::cleanup_testcase_temp_files() {
  bashunit::internal_log "cleanup_testcase_temp_files"
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    rm -rf "$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_TEST_ID}"_*
  fi
}

function bashunit::cleanup_script_temp_files() {
  bashunit::internal_log "cleanup_script_temp_files"
  if [[ -n "${BASHUNIT_CURRENT_SCRIPT_ID:-}" ]]; then
    rm -rf "$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_SCRIPT_ID}"_*
  fi
}

# shellcheck disable=SC2145
function bashunit::log() {
  if ! bashunit::env::is_dev_mode_enabled; then
    return
  fi

  local level="$1"
  shift

  case "$level" in
    info|INFO)          level="INFO" ;;
    debug|DEBUG)        level="DEBUG" ;;
    warning|WARNING)    level="WARNING" ;;
    critical|CRITICAL)  level="CRITICAL" ;;
    error|ERROR)        level="ERROR" ;;
    *) set -- "$level $@"; level="INFO" ;;
  esac

  echo "$(bashunit::current_timestamp) [$level]: $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >> "$BASHUNIT_DEV_LOG"
}

function bashunit::internal_log() {
  if ! bashunit::env::is_dev_mode_enabled || ! bashunit::env::is_internal_log_enabled; then
    return
  fi

  echo "$(bashunit::current_timestamp) [INTERNAL]: $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >> "$BASHUNIT_DEV_LOG"
}

function bashunit::print_line() {
  local length="${1:-70}"   # Default to 70 if not passed
  local char="${2:--}"      # Default to '-' if not passed
  printf '%*s\n' "$length" '' | tr ' ' "$char"
}

function bashunit::data_set() {
  local arg
  local first=true

  for arg in "$@"; do
    if [ "$first" = true ]; then
      printf '%q' "$arg"
      first=false
    else
      printf ' %q' "$arg"
    fi
  done
  printf ' %q\n' ""
}
