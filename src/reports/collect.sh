#!/usr/bin/env bash

# Collected per-test results: the shared arrays every report writer reads, and the API the runner calls to fill them.

# Field separator for the rows parallel workers spool. ASCII unit separator: it
# cannot appear in base64 output and is not an IFS whitespace character, so a
# run of them yields empty fields instead of collapsing.
_BASHUNIT_REPORTS_FIELD_SEP=$'\037'

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
  # Only the four fields that can hold arbitrary text are base64-encoded: a
  # failure message or a captured output carries newlines, and a path or a test
  # name (which may end in a provider's arguments) can hold anything. The other
  # five are a status word and four numbers, produced by this file's own
  # callers, so the unit separator carries them as they are.
  #
  # Encoding all nine cost fourteen `base64` forks per test -- nine here and
  # five more decoding, each with a `tr` on top -- which made `--log-junit`
  # several times more expensive than the run it was reporting on. Base64
  # output is [A-Za-z0-9+/=] and the raw fields are numeric, so no field can
  # contain the separator and the row stays one line.
  if bashunit::parallel::is_enabled; then
    local us=$_BASHUNIT_REPORTS_FIELD_SEP
    local row
    row="$(bashunit::helper::encode_base64 "$file")$us"
    row="$row$(bashunit::helper::encode_base64 "$test_name")$us"
    row="$row$status$us$duration$us$assertions$us"
    row="$row$(bashunit::helper::encode_base64 "$failure_message")$us"
    row="$row$line$us$retries$us"
    row="$row$(bashunit::helper::encode_base64 "$test_output")"
    printf '%s\n' "$row" \
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
  _BASHUNIT_REPORTS_TEST_OUTPUTS[${#_BASHUNIT_REPORTS_TEST_OUTPUTS[@]}]="$test_output"
}

##
# Replays rows spooled by parallel workers into the report arrays, in the order
# they were written. Called once in the parent before any report is generated;
# a no-op sequentially, where add_test filled the arrays directly.
##
function bashunit::reports::load_spooled() {
  bashunit::reports::is_enabled || return 0
  [ -f "${REPORTS_OUTPUT_PATH:-}" ] || return 0

  local file test_name status duration assertions failure_message line retries test_output n
  # The separator is not an IFS whitespace character, so a run of them yields
  # empty fields rather than collapsing -- which is what an absent failure
  # message or output has to produce.
  while IFS="$_BASHUNIT_REPORTS_FIELD_SEP" read -r \
    file test_name status duration assertions failure_message line retries test_output; do
    [ -n "$file" ] || continue
    local n=${#_BASHUNIT_REPORTS_TEST_FILES[@]}
    _BASHUNIT_REPORTS_TEST_FILES[n]=$(bashunit::helper::decode_base64 "$file")
    _BASHUNIT_REPORTS_TEST_NAMES[n]=$(bashunit::helper::decode_base64 "$test_name")
    _BASHUNIT_REPORTS_TEST_STATUSES[n]=$status
    _BASHUNIT_REPORTS_TEST_DURATIONS[n]=$duration
    _BASHUNIT_REPORTS_TEST_ASSERTIONS[n]=$assertions
    _BASHUNIT_REPORTS_TEST_FAILURES[n]=$(bashunit::helper::decode_base64 "$failure_message")
    _BASHUNIT_REPORTS_TEST_LINES[n]=$line
    _BASHUNIT_REPORTS_TEST_RETRIES[n]=$retries
    _BASHUNIT_REPORTS_TEST_OUTPUTS[n]=$(bashunit::helper::decode_base64 "$test_output")
  done <"$REPORTS_OUTPUT_PATH"
}
