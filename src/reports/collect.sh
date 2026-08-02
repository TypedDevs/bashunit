#!/usr/bin/env bash

# Collected per-test results: the shared arrays every report writer reads, and the API the runner calls to fill them.

# Strips ANSI CSI escape sequences (color codes, cursor moves, erase-line, ...)
# from $1. Shared by every writer's own escape/encode function below as their
# first step, so the definition of "what is an ANSI escape sequence" for
# report output lives in exactly one place instead of one regex per format.
function bashunit::reports::__strip_ansi() {
  printf '%s' "$1" | sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

_BASHUNIT_REPORTS_TEST_FILES=()
_BASHUNIT_REPORTS_TEST_NAMES=()
_BASHUNIT_REPORTS_TEST_STATUSES=()
_BASHUNIT_REPORTS_TEST_DURATIONS=()
_BASHUNIT_REPORTS_TEST_ASSERTIONS=()
_BASHUNIT_REPORTS_TEST_FAILURES=()
_BASHUNIT_REPORTS_TEST_LINES=()

function bashunit::reports::add_test_snapshot() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "snapshot"
}

function bashunit::reports::add_test_incomplete() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "incomplete"
}

function bashunit::reports::add_test_skipped() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "skipped"
}

function bashunit::reports::add_test_passed() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "passed"
}

function bashunit::reports::add_test_risky() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "risky"
}

function bashunit::reports::add_test_failed() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "failed" "$5"
}

# Returns 0 when any report output is requested.
function bashunit::reports::is_enabled() {
  [ -n "${BASHUNIT_LOG_JUNIT:-}" ] ||
    [ -n "${BASHUNIT_REPORT_HTML:-}" ] ||
    [ -n "${BASHUNIT_LOG_GHA:-}" ] ||
    [ -n "${BASHUNIT_REPORT_TAP:-}" ] ||
    [ -n "${BASHUNIT_REPORT_JSON:-}" ]
}

function bashunit::reports::add_test() {
  # Skip tracking when no report output is requested
  bashunit::reports::is_enabled || return 0

  local file="$1"
  local test_name="$2"
  local duration="$3"
  local assertions="$4"
  local status="$5"
  local failure_message="${6:-}"

  # Capture the line number from the current test location ("file:line"),
  # but only when it belongs to this test's file, so a stale location from a
  # prior test never mislabels this entry.
  local line=""
  case "${_BASHUNIT_TEST_LOCATION:-}" in
    "$file":*) line="${_BASHUNIT_TEST_LOCATION##*:}" ;;
  esac

  _BASHUNIT_REPORTS_TEST_FILES[${#_BASHUNIT_REPORTS_TEST_FILES[@]}]="$file"
  _BASHUNIT_REPORTS_TEST_NAMES[${#_BASHUNIT_REPORTS_TEST_NAMES[@]}]="$test_name"
  _BASHUNIT_REPORTS_TEST_STATUSES[${#_BASHUNIT_REPORTS_TEST_STATUSES[@]}]="$status"
  _BASHUNIT_REPORTS_TEST_ASSERTIONS[${#_BASHUNIT_REPORTS_TEST_ASSERTIONS[@]}]="$assertions"
  _BASHUNIT_REPORTS_TEST_DURATIONS[${#_BASHUNIT_REPORTS_TEST_DURATIONS[@]}]="$duration"
  _BASHUNIT_REPORTS_TEST_FAILURES[${#_BASHUNIT_REPORTS_TEST_FAILURES[@]}]="$failure_message"
  _BASHUNIT_REPORTS_TEST_LINES[${#_BASHUNIT_REPORTS_TEST_LINES[@]}]="$line"
}
