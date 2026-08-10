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
_BASHUNIT_REPORTS_TEST_RETRIES=()

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

##
# A test that passed, but not on the first attempt. Carries the retry count and
# the first attempt's failure message, which is the whole diagnostic value and
# is otherwise discarded when the retry loop overwrites the losing attempt.
# Arguments: $1 file, $2 name, $3 duration, $4 assertions, $5 first failure,
# $6 retries.
##
function bashunit::reports::add_test_flaky() {
  bashunit::reports::add_test "$1" "$2" "$3" "$4" "flaky" "$5" "$6"
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
  local retries="${7:-0}"

  # Capture the line number from the current test location ("file:line"),
  # but only when it belongs to this test's file, so a stale location from a
  # prior test never mislabels this entry.
  local line=""
  case "${_BASHUNIT_TEST_LOCATION:-}" in
    "$file":*) line="${_BASHUNIT_TEST_LOCATION##*:}" ;;
  esac

  # Under --parallel this runs inside the per-test worker, so the arrays below
  # are appended to in a process that is about to exit and the parent rebuilds
  # nothing -- every report came out with zero tests while the run stayed green.
  # Spool the row to a run-scoped file as well, the same way
  # --snapshot-report-unused crosses the fork boundary, and replay it in the
  # parent before the writers run.
  #
  # The arrays are still filled here rather than skipped: this function is also
  # called directly, in the parent, by the reports unit tests, and returning
  # early left them asserting against arrays nothing had touched. The parent
  # never reaches this path for a real parallel test, so replaying the spool
  # cannot double-count.
  #
  # Fields are base64-encoded because a failure message carries newlines and
  # arbitrary text, either of which would break a delimited line.
  if bashunit::parallel::is_enabled; then
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$(bashunit::helper::encode_base64 "$file")" \
      "$(bashunit::helper::encode_base64 "$test_name")" \
      "$(bashunit::helper::encode_base64 "$status")" \
      "$(bashunit::helper::encode_base64 "$duration")" \
      "$(bashunit::helper::encode_base64 "$assertions")" \
      "$(bashunit::helper::encode_base64 "$failure_message")" \
      "$(bashunit::helper::encode_base64 "$line")" \
      "$(bashunit::helper::encode_base64 "$retries")" \
      >>"${REPORTS_OUTPUT_PATH:-/dev/null}" 2>/dev/null || true
  fi

  _BASHUNIT_REPORTS_TEST_FILES[${#_BASHUNIT_REPORTS_TEST_FILES[@]}]="$file"
  _BASHUNIT_REPORTS_TEST_NAMES[${#_BASHUNIT_REPORTS_TEST_NAMES[@]}]="$test_name"
  _BASHUNIT_REPORTS_TEST_STATUSES[${#_BASHUNIT_REPORTS_TEST_STATUSES[@]}]="$status"
  _BASHUNIT_REPORTS_TEST_ASSERTIONS[${#_BASHUNIT_REPORTS_TEST_ASSERTIONS[@]}]="$assertions"
  _BASHUNIT_REPORTS_TEST_DURATIONS[${#_BASHUNIT_REPORTS_TEST_DURATIONS[@]}]="$duration"
  _BASHUNIT_REPORTS_TEST_FAILURES[${#_BASHUNIT_REPORTS_TEST_FAILURES[@]}]="$failure_message"
  _BASHUNIT_REPORTS_TEST_LINES[${#_BASHUNIT_REPORTS_TEST_LINES[@]}]="$line"
  _BASHUNIT_REPORTS_TEST_RETRIES[${#_BASHUNIT_REPORTS_TEST_RETRIES[@]}]="$retries"
}

##
# Replays rows spooled by parallel workers into the report arrays, in the order
# they were written. Called once in the parent before any report is generated;
# a no-op sequentially, where add_test filled the arrays directly.
##
function bashunit::reports::load_spooled() {
  bashunit::reports::is_enabled || return 0
  [ -f "${REPORTS_OUTPUT_PATH:-}" ] || return 0

  local file test_name status duration assertions failure_message line retries n
  while IFS='|' read -r file test_name status duration assertions failure_message line retries; do
    [ -n "$file" ] || continue
    local n=${#_BASHUNIT_REPORTS_TEST_FILES[@]}
    _BASHUNIT_REPORTS_TEST_FILES[n]=$(bashunit::helper::decode_base64 "$file")
    _BASHUNIT_REPORTS_TEST_NAMES[n]=$(bashunit::helper::decode_base64 "$test_name")
    _BASHUNIT_REPORTS_TEST_STATUSES[n]=$(bashunit::helper::decode_base64 "$status")
    _BASHUNIT_REPORTS_TEST_DURATIONS[n]=$(bashunit::helper::decode_base64 "$duration")
    _BASHUNIT_REPORTS_TEST_ASSERTIONS[n]=$(bashunit::helper::decode_base64 "$assertions")
    _BASHUNIT_REPORTS_TEST_FAILURES[n]=$(bashunit::helper::decode_base64 "$failure_message")
    _BASHUNIT_REPORTS_TEST_LINES[n]=$(bashunit::helper::decode_base64 "$line")
    _BASHUNIT_REPORTS_TEST_RETRIES[n]=$(bashunit::helper::decode_base64 "$retries")
  done <"$REPORTS_OUTPUT_PATH"
}
