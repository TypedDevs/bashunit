#!/bin/bash
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
  LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c "$length"
}

function temp_file() {
  local prefix=${1:-bashunit}
  mkdir -p /tmp/bashunit/tmp && chmod -R 777 /tmp/bashunit/tmp
  mktemp /tmp/bashunit/tmp/"$prefix".XXXXXXX
}

function temp_dir() {
  local prefix=${1:-bashunit}
  mkdir -p /tmp/bashunit/tmp && chmod -R 777 /tmp/bashunit/tmp
  mktemp -d /tmp/bashunit/tmp/"$prefix".XXXXXXX
}

function cleanup_temp_files() {
  rm -rf /tmp/bashunit/tmp/*
}

# shellcheck disable=SC2145
function log() {
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

  echo "$(current_timestamp) [$level]: $@" >> "$BASHUNIT_DEV_LOG"
}
