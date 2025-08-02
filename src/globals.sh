#!/usr/bin/env bash
set -euo pipefail

# This file provides a set of global functions to developers.

function current_dir() {
  dirname "${BASH_SOURCE[1]}"
}

function current_filename() {
  basename "${BASH_SOURCE[1]}"
}

function caller_filename() {
  dirname "${BASH_SOURCE[2]}"
}

function caller_line() {
  echo "${BASH_LINENO[1]}"
}

function current_timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

function is_command_available() {
  command -v "$1" >/dev/null 2>&1
}

function random_str() {
  local length=${1:-6}
  local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  local str=''
  for (( i=0; i<length; i++ )); do
    str="${str}${chars:RANDOM%${#chars}:1}"
  done
  echo "$str"
}

function temp_file() {
  local prefix=${1:-bashunit}
  local base_dir="${TMPDIR:-/tmp}/bashunit/tmp"
  mkdir -p "$base_dir" && chmod -R 777 "$base_dir"
  local test_prefix=""
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  fi
  mktemp "$base_dir/${test_prefix}${prefix}.XXXXXXX"
}

function temp_dir() {
  local prefix=${1:-bashunit}
  local base_dir="${TMPDIR:-/tmp}/bashunit/tmp"
  mkdir -p "$base_dir" && chmod -R 777 "$base_dir"
  local test_prefix=""
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  fi
  mktemp -d "$base_dir/${test_prefix}${prefix}.XXXXXXX"
}

function cleanup_temp_files() {
  internal_log "cleanup_temp_files"
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    rm -rf "${TMPDIR:-/tmp}/bashunit/tmp/${BASHUNIT_CURRENT_TEST_ID}"_*
  else
    rm -rf "${TMPDIR:-/tmp}/bashunit/tmp"/*
  fi
}

# shellcheck disable=SC2145
function log() {
  if ! env::is_dev_mode_enabled; then
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

  echo "$(current_timestamp) [$level]: $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >> "$BASHUNIT_DEV_LOG"
}

function internal_log() {
  if ! env::is_dev_mode_enabled || ! env::is_internal_log_enabled; then
    return
  fi

  echo "$(current_timestamp) [INTERNAL]: $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >> "$BASHUNIT_DEV_LOG"
}

function print_line() {
  local length="${1:-70}"   # Default to 70 if not passed
  local char="${2:--}"      # Default to '-' if not passed
  printf '%*s\n' "$length" '' | tr ' ' "$char"
}
