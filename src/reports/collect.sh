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
_BASHUNIT_REPORTS_TEST_OUTPUTS=()

# The captured output of the test about to be recorded. The runner sets this
# once per test before the add_test_* dispatch, so the report writers can carry
# it (JUnit <system-out>) without threading one more argument through every
# wrapper; add_test consumes and clears it.
_BASHUNIT_REPORTS_CURRENT_OUTPUT=""
_BASHUNIT_REPORTS_FILE_ORDINAL=0
_BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL=0
_BASHUNIT_REPORTS_WORKER_RECORD_ORDINAL=0
_BASHUNIT_REPORTS_RECORD_SCOPE=control

function bashunit::reports::set_current_test_output() {
  _BASHUNIT_REPORTS_CURRENT_OUTPUT="$1"
}

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
    [ -n "${BASHUNIT_REPORT_JSON:-}" ] ||
    [ -n "${BASHUNIT_REPORT_MD:-}" ] ||
    bashunit::env::is_json_output_enabled ||
    bashunit::env::is_junit_output_enabled ||
    bashunit::env::should_append_step_summary ||
    bashunit::env::should_print_gha_annotations
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
  local test_output="$_BASHUNIT_REPORTS_CURRENT_OUTPUT"
  _BASHUNIT_REPORTS_CURRENT_OUTPUT=""

  # Capture the line number from the current test location ("file:line"),
  # but only when it belongs to this test's file, so a stale location from a
  # prior test never mislabels this entry. Resolved here rather than per test:
  # reports are opt-in and this function has already returned when they are off
  # (#1346).
  bashunit::runner::ensure_test_location
  local line=""
  case "${_BASHUNIT_TEST_LOCATION:-}" in
    "$file":*) line="${_BASHUNIT_TEST_LOCATION##*:}" ;;
  esac

  # Sidecars avoid Bash 3's bytewise read on large diagnostics.
  if bashunit::parallel::is_enabled; then
    local file_order="00000000${_BASHUNIT_REPORTS_FILE_ORDINAL:-0}"
    file_order="${file_order: -8}"
    local row_order="00000000${_BASHUNIT_RUNNER_RESULT_ORDINAL:-0}"
    row_order="${row_order: -8}"
    local record_kind=0
    local record_order=00000000
    if [ "$_BASHUNIT_REPORTS_RECORD_SCOPE" = worker ]; then
      _BASHUNIT_REPORTS_WORKER_RECORD_ORDINAL=$((_BASHUNIT_REPORTS_WORKER_RECORD_ORDINAL + 1))
      record_order="00000000$_BASHUNIT_REPORTS_WORKER_RECORD_ORDINAL"
      record_order="${record_order: -8}"
    else
      record_kind=1
      _BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL=$((_BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL + 1))
      record_order="00000000$_BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL"
      record_order="${record_order: -8}"
    fi
    local record_token="$file_order$row_order$record_kind$record_order"
    local record="${REPORTS_OUTPUT_PATH:-/dev/null}.$record_token.record"
    local has_failure=0
    local has_output=0
    local write_failed=false
    if [ -n "$failure_message" ]; then
      has_failure=1
      printf '%s_' "$failure_message" >"$record.failure" 2>/dev/null || write_failed=true
    fi
    if [ -n "$test_output" ]; then
      has_output=1
      printf '%s_' "$test_output" >"$record.output" 2>/dev/null || write_failed=true
    fi
    if [ "$write_failed" = false ]; then
      printf '%s\0' "$file" "$test_name" "$status" "$duration" "$assertions" "$line" "$retries" \
        "$has_failure" "$has_output" >"$record" 2>/dev/null || write_failed=true
    fi
    if [ "$write_failed" = false ]; then
      # A 26-byte builtin append publishes the complete row in completion order.
      printf '%s\n' "$record_token" >>"${REPORTS_OUTPUT_PATH:-/dev/null}" 2>/dev/null || write_failed=true
    fi
    if [ "$write_failed" = true ]; then
      printf 'bashunit: unable to write report record %s\n' "$record" >&2
    fi
  fi

  _BASHUNIT_REPORTS_TEST_FILES[${#_BASHUNIT_REPORTS_TEST_FILES[@]}]="$file"
  _BASHUNIT_REPORTS_TEST_NAMES[${#_BASHUNIT_REPORTS_TEST_NAMES[@]}]="$test_name"
  _BASHUNIT_REPORTS_TEST_STATUSES[${#_BASHUNIT_REPORTS_TEST_STATUSES[@]}]="$status"
  _BASHUNIT_REPORTS_TEST_ASSERTIONS[${#_BASHUNIT_REPORTS_TEST_ASSERTIONS[@]}]="$assertions"
  _BASHUNIT_REPORTS_TEST_DURATIONS[${#_BASHUNIT_REPORTS_TEST_DURATIONS[@]}]="$duration"
  _BASHUNIT_REPORTS_TEST_FAILURES[${#_BASHUNIT_REPORTS_TEST_FAILURES[@]}]="$failure_message"
  _BASHUNIT_REPORTS_TEST_LINES[${#_BASHUNIT_REPORTS_TEST_LINES[@]}]="$line"
  _BASHUNIT_REPORTS_TEST_RETRIES[${#_BASHUNIT_REPORTS_TEST_RETRIES[@]}]="$retries"
  _BASHUNIT_REPORTS_TEST_OUTPUTS[${#_BASHUNIT_REPORTS_TEST_OUTPUTS[@]}]="$test_output"
}

##
# Replays rows spooled by parallel workers into the report arrays in publication
# order. Called once in the parent before any report is generated;
# a no-op sequentially, where add_test filled the arrays directly.
##
function bashunit::reports::load_spooled() {
  bashunit::reports::is_enabled || return 0
  bashunit::parallel::is_enabled || return 0
  [ -f "${REPORTS_OUTPUT_PATH:-}" ] || return 0

  # The spool is the complete record of a parallel run, so it replaces the
  # arrays rather than appending to them.
  #
  # A worker's own arrays die with it, so for a worker's row appending would be
  # right. But a file-level hook failure is recorded by the PARENT -- see
  # runner/hooks.sh record_file_hook_failure -- and add_test fills the arrays
  # for every caller while spooling only under --parallel. That row was
  # therefore in both places, and replaying it appended a second copy: a failing
  # set_up_before_script was reported as two failed tests where the console
  # summary of the same run said one.
  _BASHUNIT_REPORTS_TEST_FILES=()
  _BASHUNIT_REPORTS_TEST_NAMES=()
  _BASHUNIT_REPORTS_TEST_STATUSES=()
  _BASHUNIT_REPORTS_TEST_DURATIONS=()
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=()
  _BASHUNIT_REPORTS_TEST_FAILURES=()
  _BASHUNIT_REPORTS_TEST_LINES=()
  _BASHUNIT_REPORTS_TEST_RETRIES=()
  _BASHUNIT_REPORTS_TEST_OUTPUTS=()

  local record_token record file test_name status duration assertions failure_message line retries test_output
  local has_failure has_output
  while IFS= read -r record_token; do
    case "$record_token" in
      *[!0-9]* | "")
        printf 'bashunit: invalid report record token %s\n' "$record_token" >&2
        continue
        ;;
    esac
    if [ "${#record_token}" -ne 25 ]; then
      printf 'bashunit: invalid report record token %s\n' "$record_token" >&2
      continue
    fi
    record="$REPORTS_OUTPUT_PATH.$record_token.record"
    if [ ! -f "$record" ]; then
      printf 'bashunit: missing report record %s\n' "$record" >&2
      continue
    fi
    if {
      IFS= read -r -d '' file &&
        IFS= read -r -d '' test_name &&
        IFS= read -r -d '' status &&
        IFS= read -r -d '' duration &&
        IFS= read -r -d '' assertions &&
        IFS= read -r -d '' line &&
        IFS= read -r -d '' retries &&
        IFS= read -r -d '' has_failure &&
        IFS= read -r -d '' has_output
    } <"$record"; then
      :
    else
      printf 'bashunit: incomplete report record %s\n' "$record" >&2
      continue
    fi
    failure_message=""
    test_output=""
    if [ "$has_failure" = 1 ] && [ -f "$record.failure" ]; then
      failure_message=$(<"$record.failure")
      case "$failure_message" in
      *_) failure_message="${failure_message%?}" ;;
      *) printf 'bashunit: incomplete report field %s\n' "$record.failure" >&2; continue ;;
      esac
    elif [ "$has_failure" = 1 ]; then
      printf 'bashunit: missing report field %s\n' "$record.failure" >&2
      continue
    fi
    if [ "$has_output" = 1 ] && [ -f "$record.output" ]; then
      test_output=$(<"$record.output")
      case "$test_output" in
      *_) test_output="${test_output%?}" ;;
      *) printf 'bashunit: incomplete report field %s\n' "$record.output" >&2; continue ;;
      esac
    elif [ "$has_output" = 1 ]; then
      printf 'bashunit: missing report field %s\n' "$record.output" >&2
      continue
    fi
    local n=${#_BASHUNIT_REPORTS_TEST_FILES[@]}
    _BASHUNIT_REPORTS_TEST_FILES[n]=$file
    _BASHUNIT_REPORTS_TEST_NAMES[n]=$test_name
    _BASHUNIT_REPORTS_TEST_STATUSES[n]=$status
    _BASHUNIT_REPORTS_TEST_DURATIONS[n]=$duration
    _BASHUNIT_REPORTS_TEST_ASSERTIONS[n]=$assertions
    _BASHUNIT_REPORTS_TEST_FAILURES[n]=$failure_message
    _BASHUNIT_REPORTS_TEST_LINES[n]=$line
    _BASHUNIT_REPORTS_TEST_RETRIES[n]=$retries
    _BASHUNIT_REPORTS_TEST_OUTPUTS[n]=$test_output
  done <"$REPORTS_OUTPUT_PATH"
}
