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
    str+="${chars:RANDOM%${#chars}:1}"
  done
  echo "$str"
}

function temp_file() {
  local prefix=${1:-bashunit}
  mkdir -p /tmp/bashunit/tmp && chmod -R 777 /tmp/bashunit/tmp
  local test_prefix=""
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  fi
  mktemp /tmp/bashunit/tmp/"${test_prefix}${prefix}".XXXXXXX
}

function temp_dir() {
  local prefix=${1:-bashunit}
  mkdir -p /tmp/bashunit/tmp && chmod -R 777 /tmp/bashunit/tmp
  local test_prefix=""
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  fi
  mktemp -d /tmp/bashunit/tmp/"${test_prefix}${prefix}".XXXXXXX
}

function cleanup_temp_files() {
  internal_log "debug" "cleanup_temp_files"
  if [[ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]]; then
    rm -rf /tmp/bashunit/tmp/"${BASHUNIT_CURRENT_TEST_ID}"_*
  else
    rm -rf /tmp/bashunit/tmp/*
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

  local caller_fn="${FUNCNAME[1]:-main}"
  echo "$(current_timestamp) [$level] ($caller_fn): $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >> "$BASHUNIT_DEV_LOG"
}

function internal_log() {
  if ! env::is_dev_mode_enabled || ! env::is_internal_log_enabled; then
    return
  fi

  echo "$(current_timestamp) [INTERNAL]: $*" >> "$BASHUNIT_DEV_LOG"
}

function print_line() {
  local length="${1:-70}"   # Default to 70 if not passed
  local char="${2:--}"      # Default to '-' if not passed
  printf '%*s\n' "$length" '' | tr ' ' "$char"
}
