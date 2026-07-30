#!/usr/bin/env bash

# Hot-path result helpers below return their value via a dedicated global slot
# (`_BASHUNIT_RUNNER_*_OUT`) instead of stdout. This avoids the per-test
# `$(...)` subshell capture that dominated the result-parsing hot path. Callers
# invoke the helper and immediately read the slot:
#
#   bashunit::runner::extract_subshell_type "$subshell_output"
#   type=$_BASHUNIT_RUNNER_TYPE_OUT
#
# A dedicated slot per helper (rather than one shared slot) means nested or
# adjacent calls cannot clobber each other and callers don't need to copy out
# before every other helper runs.
_BASHUNIT_RUNNER_FIELD_OUT=""
_BASHUNIT_RUNNER_TOTAL_OUT=""
_BASHUNIT_RUNNER_TYPE_OUT=""
_BASHUNIT_RUNNER_OUTPUT_OUT=""
_BASHUNIT_RUNNER_INTERP_OUT=""
_BASHUNIT_RUNNER_COUNTS_FAILED_OUT=0
_BASHUNIT_RUNNER_COUNTS_PASSED_OUT=0
_BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT=0
_BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT=0
_BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT=0
_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT=0
_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT=""
_BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT=""
# Per-suite ordinal for naming a parallel worker's `.result` file. Set by
# call_test_functions (single-threaded dispatch) just before each backgrounded
# run_test; the fork inherits the value, so every test in a file gets a unique,
# collision-free name in its per-suite dir without forking mktemp/mv.
_BASHUNIT_RUNNER_RESULT_ORDINAL=0
# Suffix appended to a passed-test line when it only passed after retrying.
_BASHUNIT_RETRY_NOTE=""

# Writes the value of an encoded field (##KEY=value##) into _BASHUNIT_RUNNER_FIELD_OUT.
# Arguments: $1 test_execution_result, $2 key
function bashunit::runner::extract_encoded_field() {
  local test_execution_result=$1
  local key=$2
  local marker="##${key}="
  case "$test_execution_result" in
  *"$marker"*)
    local rest="${test_execution_result#*"$marker"}"
    _BASHUNIT_RUNNER_FIELD_OUT="${rest%%##*}"
    ;;
  *) _BASHUNIT_RUNNER_FIELD_OUT="" ;;
  esac
}

# Writes the sum of all ASSERTIONS_* counters into _BASHUNIT_RUNNER_TOTAL_OUT.
# Arguments: $1 test_execution_result
function bashunit::runner::compute_total_assertions() {
  local test_execution_result=$1
  local failed passed skipped incomplete snapshot
  failed="${test_execution_result##*##ASSERTIONS_FAILED=}"
  failed="${failed%%##*}"
  passed="${test_execution_result##*##ASSERTIONS_PASSED=}"
  passed="${passed%%##*}"
  skipped="${test_execution_result##*##ASSERTIONS_SKIPPED=}"
  skipped="${skipped%%##*}"
  incomplete="${test_execution_result##*##ASSERTIONS_INCOMPLETE=}"
  incomplete="${incomplete%%##*}"
  snapshot="${test_execution_result##*##ASSERTIONS_SNAPSHOT=}"
  snapshot="${snapshot%%##*}"
  # A result that never reached the payload (a SIGKILLed subshell, raw stderr)
  # leaves every ##KEY= strip a no-op, so these fields hold arbitrary text. That
  # text is not "0" to `$(( ))`: it is a fatal arithmetic syntax error that
  # aborts the run. One `case` over the concatenation costs no fork and keeps
  # the happy path (all digits, or empty for an absent counter) untouched.
  case "$failed$passed$skipped$incomplete$snapshot" in
  *[!0-9]*) failed=0 passed=0 skipped=0 incomplete=0 snapshot=0 ;;
  esac
  local total
  total=$((failed + passed + skipped))
  total=$((total + incomplete + snapshot))
  _BASHUNIT_RUNNER_TOTAL_OUT=$total
}

# Writes the subshell type marker (text inside leading [...]) into _BASHUNIT_RUNNER_TYPE_OUT.
# Arguments: $1 subshell_output
function bashunit::runner::extract_subshell_type() {
  local subshell_output=$1
  local type="${subshell_output%%]*}"
  _BASHUNIT_RUNNER_TYPE_OUT="${type#[}"
}

# Writes the subshell output (minus the leading [type] marker, with embedded
# status markers replaced by newlines) into _BASHUNIT_RUNNER_OUTPUT_OUT.
# Arguments: $1 subshell_output
function bashunit::runner::format_subshell_output() {
  local subshell_output=$1
  local line="${subshell_output#*]}"
  line=${line//\[failed\]/$'\n'}
  line=${line//\[skipped\]/$'\n'}
  line=${line//\[incomplete\]/$'\n'}
  _BASHUNIT_RUNNER_OUTPUT_OUT=$line
}

# Writes the decoded subshell output into _BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT.
# The empty case (a passing test with no captured output) short-circuits with
# no subshell at all; only the non-empty path pays the base64 fork (#762/#764).
# Arguments: $1 test_execution_result
function bashunit::runner::decode_subshell_output() {
  local test_execution_result="$1"

  local test_output_base64="${test_execution_result##*##TEST_OUTPUT=}"
  test_output_base64="${test_output_base64%%##*}"
  if [ -z "$test_output_base64" ] || [ "$test_output_base64" = "$_BASHUNIT_BASE64_EMPTY_SENTINEL" ]; then
    _BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT=""
    return
  fi
  _BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT="$(bashunit::helper::decode_base64 "$test_output_base64")"
}

function bashunit::runner::is_simple_progress_output() {
  local output="$1"

  [ -n "$output" ] || return 1

  local color
  for color in \
    "$_BASHUNIT_COLOR_DEFAULT" \
    "$_BASHUNIT_COLOR_PASSED" \
    "$_BASHUNIT_COLOR_FAILED" \
    "$_BASHUNIT_COLOR_SKIPPED" \
    "$_BASHUNIT_COLOR_INCOMPLETE" \
    "$_BASHUNIT_COLOR_SNAPSHOT" \
    "$_BASHUNIT_COLOR_RISKY"; do
    [ -n "$color" ] && output="${output//"$color"/}"
  done

  local i
  local char
  for ((i = 0; i < ${#output}; i++)); do
    char="${output:$i:1}"
    case "$char" in
    "." | "F" | "S" | "I" | "N" | "R" | "E" | "?") ;;
    *) return 1 ;;
    esac
  done

  return 0
}

function bashunit::runner::line_exists_in_output() {
  local needle="$1"
  local haystack="$2"
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    [ "$line" = "$needle" ] && return 0
  done <<<"$haystack"

  return 1
}

function bashunit::runner::extract_assertion_runtime_output() {
  local runtime_output="$1"
  local rendered_assertion_output="$2"
  local filtered_output=""
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    if bashunit::runner::line_exists_in_output "$line" "$rendered_assertion_output"; then
      continue
    fi
    if bashunit::runner::is_simple_progress_output "$line"; then
      continue
    fi

    [ -n "$filtered_output" ] && filtered_output="$filtered_output"$'\n'
    filtered_output="$filtered_output$line"
  done <<<"$runtime_output"

  runtime_output="$filtered_output"

  while [ -n "$runtime_output" ]; do
    case "$runtime_output" in
    *$'\n') runtime_output="${runtime_output%$'\n'}" ;;
    *) break ;;
    esac
  done

  echo "$runtime_output"
}

# shellcheck disable=SC2295
##
# Parses the encoded per-test result's last line into the counts out-slots
# (_BASHUNIT_RUNNER_COUNTS_*_OUT). Pure read: never mutates the cumulative
# _BASHUNIT_ASSERTIONS_* / _BASHUNIT_TEST_EXIT_CODE state, so the retry loop can
# judge an attempt's outcome without committing it.
##
function bashunit::runner::extract_result_counts() {
  local execution_result=$1

  local result_line
  result_line="${execution_result##*$'\n'}"

  local assertions_failed=0
  local assertions_passed=0
  local assertions_skipped=0
  local assertions_incomplete=0
  local assertions_snapshot=0
  local test_exit_code=0

  # Extract values using parameter expansion instead of spawning grep/sed subprocesses
  case "$result_line" in
  *"ASSERTIONS_FAILED="*"##ASSERTIONS_PASSED="*)
    local _tail
    _tail="${result_line##*ASSERTIONS_FAILED=}"
    assertions_failed="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_PASSED=}"
    assertions_passed="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_SKIPPED=}"
    assertions_skipped="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_INCOMPLETE=}"
    assertions_incomplete="${_tail%%##*}"
    _tail="${result_line##*ASSERTIONS_SNAPSHOT=}"
    assertions_snapshot="${_tail%%##*}"
    _tail="${result_line##*TEST_EXIT_CODE=}"
    test_exit_code="${_tail%%##*}"
    # Strip any trailing non-digit suffix (end of line) from the final field
    test_exit_code="${test_exit_code%%[!0-9]*}"
    : "${assertions_failed:=0}"
    : "${assertions_passed:=0}"
    : "${assertions_skipped:=0}"
    : "${assertions_incomplete:=0}"
    : "${assertions_snapshot:=0}"
    : "${test_exit_code:=0}"
    ;;
  esac

  _BASHUNIT_RUNNER_COUNTS_FAILED_OUT=$assertions_failed
  _BASHUNIT_RUNNER_COUNTS_PASSED_OUT=$assertions_passed
  _BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT=$assertions_skipped
  _BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT=$assertions_incomplete
  _BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT=$assertions_snapshot
  _BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT=$test_exit_code
}
