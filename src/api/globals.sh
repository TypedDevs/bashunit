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

function bashunit::is_command_available() {
  command -v "$1" >/dev/null 2>&1
}

##
# Records that the owning test created something under BASHUNIT_TEMP_DIR, so
# the EXIT trap can decide whether to clean up without reading the directory.
# A redirect, not a fork. Nothing to mark when neither id is set: the file is
# then not owned by a test and the trap never looks for it.
# Arguments: $1 - "<id>_" prefix, possibly empty
##
function bashunit::_mark_temp_owner() {
  local test_prefix=$1
  if [ -n "$test_prefix" ]; then
    : >"$BASHUNIT_TEMP_DIR/${test_prefix}.mark" 2>/dev/null || true
  fi
}

function bashunit::temp_file() {
  local prefix=${1:-bashunit}
  local test_prefix=""
  if [ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]; then
    # We're inside a test function - use test ID
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  elif [ -n "${BASHUNIT_CURRENT_SCRIPT_ID:-}" ]; then
    # We're at script level (e.g., in set_up_before_script) - use script ID
    test_prefix="${BASHUNIT_CURRENT_SCRIPT_ID}_"
  fi
  bashunit::_mark_temp_owner "$test_prefix"
  "$MKTEMP" "$BASHUNIT_TEMP_DIR/${test_prefix}${prefix}.XXXXXXX"
}

function bashunit::temp_dir() {
  local prefix=${1:-bashunit}
  local test_prefix=""
  if [ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]; then
    # We're inside a test function - use test ID
    test_prefix="${BASHUNIT_CURRENT_TEST_ID}_"
  elif [ -n "${BASHUNIT_CURRENT_SCRIPT_ID:-}" ]; then
    # We're at script level (e.g., in set_up_before_script) - use script ID
    test_prefix="${BASHUNIT_CURRENT_SCRIPT_ID}_"
  fi
  bashunit::_mark_temp_owner "$test_prefix"
  "$MKTEMP" -d "$BASHUNIT_TEMP_DIR/${test_prefix}${prefix}.XXXXXXX"
}

function bashunit::cleanup_testcase_temp_files() {
  bashunit::internal_log "cleanup_testcase_temp_files"
  if [ -n "${BASHUNIT_CURRENT_TEST_ID:-}" ]; then
    # Stat one known path before globbing. Expanding the glob makes bash read
    # the whole of BASHUNIT_TEMP_DIR, which is shared and persists between runs
    # -- every file an interrupted run left behind is then re-examined by every
    # test of every later run. It can never match one: the id carries this
    # run's $$, so the scan is pure overhead. Measured on a 100-test file, a
    # directory holding 5000 leftovers took the run from 498ms to 978ms (#1269).
    #
    # The marker is written by temp_file/temp_dir, so its absence means this
    # test created nothing and there is nothing to remove. It is named with the
    # same "<id>_" prefix, so the rm below takes it along with the rest.
    if [ ! -e "$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_TEST_ID}_.mark" ]; then
      return 0
    fi
    # Probe the glob in pure bash first: most tests create no temp file, so
    # skipping the rm avoids a fork per test (#764). A non-matching glob either
    # stays literal (nullglob off) or yields an empty array (nullglob on);
    # ${matches[0]:-} handles both under set -u, and [ -e ] is false in each
    # case. temp_file runs in a $(...) subshell, so a global flag could not
    # reach this trap; checking the filesystem is the only reliable signal.
    # Declare and assign separately: bash 3.0 does not expand a compound array
    # assignment attached to `local`, it stores the literal "(glob)" instead.
    local matches
    matches=("$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_TEST_ID}"_*)
    # if-form, not `[ ] && rm`: as the function's last statement the skip path
    # would return 1, which is a death sentence for callers under set -e (#836)
    if [ -e "${matches[0]:-}" ]; then
      rm -rf "${matches[@]}"
    fi
  fi
}

function bashunit::cleanup_script_temp_files() {
  bashunit::internal_log "cleanup_script_temp_files"
  if [ -n "${BASHUNIT_CURRENT_SCRIPT_ID:-}" ]; then
    rm -rf "$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_SCRIPT_ID}"_*
  fi
}

function bashunit::print_line() {
  local length="${1:-70}" # Default to 70 if not passed
  local char="${2:--}"    # Default to '-' if not passed
  printf '%*s\n' "$length" '' | tr ' ' "$char"
}

function bashunit::data_set() {
  local arg
  local first=true

  for arg in "$@"; do
    if [ "$first" = true ]; then
      # Bash 3.0 compatible: printf '%q' "" produces nothing in Bash 3.0
      if [ -z "$arg" ]; then
        printf "''"
      else
        printf '%q' "$arg"
      fi
      first=false
    else
      if [ -z "$arg" ]; then
        printf " ''"
      else
        printf ' %q' "$arg"
      fi
    fi
  done
  # Sentinel empty string at end
  printf " ''\n"
}
