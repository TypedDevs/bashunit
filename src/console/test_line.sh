#!/usr/bin/env bash

# The per-test result lines: passed, failed, skipped, incomplete, snapshot, risky, error.

function bashunit::console_results::print_successful_test() {
  local test_name=$1
  shift
  local duration=${1:-"0"}
  shift

  # Pure-bash concatenation (the printf only did %s substitution) to avoid a
  # $(...) fork per passing test (#764).
  local line
  if [ -z "$*" ]; then
    line="${_BASHUNIT_COLOR_PASSED}✓ Passed${_BASHUNIT_COLOR_DEFAULT}: ${test_name}"
  else
    local quoted_args=""
    local arg
    for arg in "$@"; do
      if [ -z "$quoted_args" ]; then
        quoted_args="'$arg'"
      else
        quoted_args="$quoted_args, '$arg'"
      fi
    done
    line="${_BASHUNIT_COLOR_PASSED}✓ Passed${_BASHUNIT_COLOR_DEFAULT}: ${test_name} (${quoted_args})"
  fi

  # Retry annotation (e.g. " (retry 1/2)") set by the runner when a test only
  # passed after retrying; empty in the common no-retry path.
  line="${line}${_BASHUNIT_RETRY_NOTE:-}"

  local full_line=$line
  if bashunit::env::is_show_execution_time_enabled; then
    bashunit::console_results::format_duration_to_slot "$duration"
    full_line="$(bashunit::str::rpad "$line" "$_BASHUNIT_CONSOLE_DURATION_OUT")"
  fi

  bashunit::console_results::print_line "successful" "$full_line"
}


##
# Returns a faint "    at <file>:<line>" suffix (preceded by a newline) pointing
# at the currently running test function, or an empty string when the location
# is unknown. Used to append source context to failure output.
##
function bashunit::console_results::test_location_suffix() {
  local location=${_BASHUNIT_TEST_LOCATION:-}
  if [ -z "$location" ]; then
    return 0
  fi

  printf "\n    ${_BASHUNIT_COLOR_FAINT}at %s${_BASHUNIT_COLOR_DEFAULT}" "$location"
}


function bashunit::console_results::print_failure_message() {
  local test_name=$1
  local failure_message=$2

  # Absorbed by an open bashunit::assert_once marker: see print_failed_test.
  if [ "${_BASHUNIT_ASSERT_ONCE_ACTIVE:-0}" -eq 1 ]; then
    if bashunit::assert::once_is_absorbing; then
      bashunit::assert::once_absorb_message "$failure_message" "" ""
      return 0
    fi
  fi

  local line
  line="$(printf "\
${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}Message:${_BASHUNIT_COLOR_DEFAULT} \
${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}\n" \
    "${test_name}" "${failure_message}")"

  line="$line$(bashunit::console_results::test_location_suffix)"

  bashunit::console_results::print_line "failure" "$line"
}


function bashunit::console_results::print_failed_test() {
  local function_name=$1
  local expected=$2
  local failure_condition_message=$3
  local actual=$4
  local extra_key=${5-}
  local extra_value=${6-}
  # Free-form block appended verbatim below the failure (already indented by the
  # caller). The spy assertions use it to dump the recorded call log.
  local details=${7-}

  # Absorbed by an open bashunit::assert_once marker: keep the message as the
  # no-label fallback and print nothing, so the composed assertion reports once.
  if [ "${_BASHUNIT_ASSERT_ONCE_ACTIVE:-0}" -eq 1 ]; then
    if bashunit::assert::once_is_absorbing; then
      bashunit::assert::once_absorb_message "$expected" \
        "$failure_condition_message" "$actual"
      return 0
    fi
  fi

  # For multiline values, render a unified diff below the header (git required,
  # opt out with BASHUNIT_NO_DIFF). Single-line output stays byte-identical.
  local show_diff=false
  case "$expected$actual" in
  *$'\n'*)
    if bashunit::env::is_diff_enabled && bashunit::dependencies::has_git; then
      show_diff=true
    fi
    ;;
  esac

  local display_expected=$expected
  local display_actual=$actual
  if [ "$show_diff" = true ]; then
    display_expected="$(bashunit::console_results::first_line_ellipsis "$expected")"
    display_actual="$(bashunit::console_results::first_line_ellipsis "$actual")"
  fi

  local line
  line="$(printf "\
${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}Expected${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}
    ${_BASHUNIT_COLOR_FAINT}%s${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}\n" \
    "${function_name}" "${display_expected}" "${failure_condition_message}" "${display_actual}")"

  if [ "$show_diff" = true ]; then
    local _expected_file _actual_file
    _expected_file="$(bashunit::temp_file diff_expected)"
    _actual_file="$(bashunit::temp_file diff_actual)"
    printf '%s\n' "$expected" >"$_expected_file"
    printf '%s\n' "$actual" >"$_actual_file"
    line="$line
$(bashunit::console_results::render_diff "$_expected_file" "$_actual_file")"
    rm -f "$_expected_file" "$_actual_file"
  fi

  if [ -n "$extra_key" ]; then
    line="$line$(printf "\

    ${_BASHUNIT_COLOR_FAINT}%s${_BASHUNIT_COLOR_DEFAULT} ${_BASHUNIT_COLOR_BOLD}'%s'${_BASHUNIT_COLOR_DEFAULT}\n" \
      "${extra_key}" "${extra_value}")"
  fi

  if [ -n "$details" ]; then
    line="$line
$details"
  fi

  line="$line$(bashunit::console_results::test_location_suffix)"

  bashunit::console_results::print_line "failed" "$line"
}


function bashunit::console_results::print_failed_snapshot_test() {
  local function_name=$1
  local snapshot_file=$2
  local actual_content=${3-}

  local line
  line="$(printf "${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}Expected to match the snapshot${_BASHUNIT_COLOR_DEFAULT}
    ${_BASHUNIT_COLOR_FAINT}Snapshot: %s${_BASHUNIT_COLOR_DEFAULT}
    ${_BASHUNIT_COLOR_FAINT}Re-record with '--snapshot-update'${_BASHUNIT_COLOR_DEFAULT}\n" \
    "$function_name" "$snapshot_file")"

  if bashunit::dependencies::has_git; then
    local actual_file="${snapshot_file}.tmp"
    echo "$actual_content" >"$actual_file"

    line="$line
$(bashunit::console_results::render_diff "$snapshot_file" "$actual_file")"
    rm "$actual_file"
  else
    line="$line
$(bashunit::console_results::snapshot_line_diff \
      "$(cat "$snapshot_file")" "$actual_content")"
  fi

  bashunit::console_results::print_line "failed_snapshot" "$line"
}


function bashunit::console_results::print_skipped_test() {
  local function_name=$1
  local reason=${2-}

  local line
  line="$(printf "${_BASHUNIT_COLOR_SKIPPED}↷ Skipped${_BASHUNIT_COLOR_DEFAULT}: %s\n" "${function_name}")"

  if [ -n "$reason" ]; then
    line="$line$(printf "${_BASHUNIT_COLOR_FAINT}    %s${_BASHUNIT_COLOR_DEFAULT}\n" "${reason}")"
  fi

  bashunit::console_results::print_line "skipped" "$line"
}


function bashunit::console_results::print_incomplete_test() {
  local function_name=$1
  local pending=${2-}

  local line
  line="$(printf "${_BASHUNIT_COLOR_INCOMPLETE}✒ Incomplete${_BASHUNIT_COLOR_DEFAULT}: %s\n" "${function_name}")"

  if [ -n "$pending" ]; then
    line="$line$(printf "${_BASHUNIT_COLOR_FAINT}    %s${_BASHUNIT_COLOR_DEFAULT}\n" "${pending}")"
  fi

  bashunit::console_results::print_line "incomplete" "$line"
}


function bashunit::console_results::print_snapshot_test() {
  local function_name=$1
  local test_name
  test_name=$(bashunit::helper::normalize_test_function_name "$function_name")

  local line
  line="$(printf "${_BASHUNIT_COLOR_SNAPSHOT}✎ Snapshot${_BASHUNIT_COLOR_DEFAULT}: %s\n" "${test_name}")"

  bashunit::console_results::print_line "snapshot" "$line"
}


function bashunit::console_results::print_risky_test() {
  local test_name=$1
  local duration=${2:-"0"}

  local line
  line=$(printf "%s⚠ Risky%s: %s" "$_BASHUNIT_COLOR_RISKY" "$_BASHUNIT_COLOR_DEFAULT" "$test_name")

  local full_line=$line
  if bashunit::env::is_show_execution_time_enabled; then
    local time_display
    time_display=$(bashunit::console_results::format_duration "$duration")
    full_line="$(bashunit::str::rpad "$line" "$time_display")"
  fi

  bashunit::console_results::print_line "risky" "$full_line"
}


function bashunit::console_results::print_error_test() {
  local function_name=$1
  local error="$2"
  local raw_output="${3:-}"

  local test_name
  test_name=$(bashunit::helper::normalize_test_function_name "$function_name")

  local line
  line="$(printf "${_BASHUNIT_COLOR_FAILED}✗ Error${_BASHUNIT_COLOR_DEFAULT}: %s
    ${_BASHUNIT_COLOR_FAINT}%s${_BASHUNIT_COLOR_DEFAULT}\n" "${test_name}" "${error}")"

  if [ -n "$raw_output" ] && bashunit::env::is_show_output_on_failure_enabled; then
    line="$line$(printf "    %sOutput:%s\n" "${_BASHUNIT_COLOR_FAINT}" "${_BASHUNIT_COLOR_DEFAULT}")"
    local output_line
    while IFS= read -r output_line; do
      line="$line$(printf "      %s\n" "$output_line")"
    done <<<"$raw_output"
  fi

  line="$line$(bashunit::console_results::test_location_suffix)"

  bashunit::console_results::print_line "error" "$line"
}


##
# Render stderr a parallel worker wrote outside any test body.
# A sequential run lets this straight through to the terminal; parallel workers
# have it captured per file so concurrent writes cannot shred the progress
# line. Attributed to the file, not a test: it is emitted where no test owns it
# (data providers, hook plumbing). Test-body stderr is merged into the captured
# stdout and still surfaces in that test's own failure block.
# Arguments: $1 - test file the worker ran, $2 - captured stderr file
##
function bashunit::console_results::print_worker_stderr() {
  local test_file="$1"
  local stderr_file="$2"

  # To stderr, which is where this text came from: on stdout it landed ahead of
  # the document `--output json|junit` promises that stream is, so a worker that
  # wrote anything to stderr -- a failing `set_up`, for one -- made the report
  # unparseable.
  printf "\n%sStderr from %s%s\n" \
    "$_BASHUNIT_COLOR_SKIPPED" "$test_file" "$_BASHUNIT_COLOR_DEFAULT" >&2
  sed 's/^/|/' "$stderr_file" >&2
}
