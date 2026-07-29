#!/usr/bin/env bash
# shellcheck disable=SC2155

_BASHUNIT_TOTAL_TESTS_COUNT=0

function bashunit::console_results::render_result() {
  if [ "$(bashunit::state::is_duplicated_test_functions_found)" = true ]; then
    bashunit::console_results::print_execution_time
    printf "%s%s%s\n" "${_BASHUNIT_COLOR_RETURN_ERROR}" "Duplicate test functions found" "${_BASHUNIT_COLOR_DEFAULT}"
    printf "File with duplicate functions: %s\n" "$(bashunit::state::get_file_with_duplicated_function_names)"
    printf "Duplicate functions: %s\n" "$(bashunit::state::get_duplicated_function_names)"
    return 1
  fi

  if bashunit::env::is_tap_output_enabled; then
    printf "1..%d\n" "$_BASHUNIT_TOTAL_TESTS_COUNT"
    if [ "$_BASHUNIT_TESTS_FAILED" -gt 0 ]; then
      return 1
    fi
    return 0
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n\n"
  fi

  # Cache state values to avoid repeated subshell invocations
  local tests_passed=$_BASHUNIT_TESTS_PASSED
  local tests_skipped=$_BASHUNIT_TESTS_SKIPPED
  local tests_incomplete=$_BASHUNIT_TESTS_INCOMPLETE
  local tests_snapshot=$_BASHUNIT_TESTS_SNAPSHOT
  local tests_failed=$_BASHUNIT_TESTS_FAILED
  local tests_risky=$_BASHUNIT_TESTS_RISKY
  local assertions_passed=$_BASHUNIT_ASSERTIONS_PASSED
  local assertions_skipped=$_BASHUNIT_ASSERTIONS_SKIPPED
  local assertions_incomplete=$_BASHUNIT_ASSERTIONS_INCOMPLETE
  local assertions_snapshot=$_BASHUNIT_ASSERTIONS_SNAPSHOT
  local assertions_failed=$_BASHUNIT_ASSERTIONS_FAILED

  local total_tests=0
  total_tests=$((total_tests + tests_passed))
  total_tests=$((total_tests + tests_skipped))
  total_tests=$((total_tests + tests_incomplete))
  total_tests=$((total_tests + tests_snapshot))
  total_tests=$((total_tests + tests_failed))
  total_tests=$((total_tests + tests_risky))

  local total_assertions=0
  total_assertions=$((total_assertions + assertions_passed))
  total_assertions=$((total_assertions + assertions_skipped))
  total_assertions=$((total_assertions + assertions_incomplete))
  total_assertions=$((total_assertions + assertions_snapshot))
  total_assertions=$((total_assertions + assertions_failed))

  printf "%sTests:     %s" "$_BASHUNIT_COLOR_FAINT" "$_BASHUNIT_COLOR_DEFAULT"
  if [ "$tests_passed" -gt 0 ] || [ "$assertions_passed" -gt 0 ]; then
    printf " %s%s passed%s," "$_BASHUNIT_COLOR_PASSED" "$tests_passed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_skipped" -gt 0 ] || [ "$assertions_skipped" -gt 0 ]; then
    printf " %s%s skipped%s," "$_BASHUNIT_COLOR_SKIPPED" "$tests_skipped" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_incomplete" -gt 0 ] || [ "$assertions_incomplete" -gt 0 ]; then
    printf " %s%s incomplete%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$tests_incomplete" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_snapshot" -gt 0 ] || [ "$assertions_snapshot" -gt 0 ]; then
    printf " %s%s snapshot%s," "$_BASHUNIT_COLOR_SNAPSHOT" "$tests_snapshot" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_failed" -gt 0 ] || [ "$assertions_failed" -gt 0 ]; then
    printf " %s%s failed%s," "$_BASHUNIT_COLOR_FAILED" "$tests_failed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_risky" -gt 0 ]; then
    printf " %s%s risky%s," "$_BASHUNIT_COLOR_RISKY" "$tests_risky" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_tests"

  printf "%sAssertions:%s" "$_BASHUNIT_COLOR_FAINT" "$_BASHUNIT_COLOR_DEFAULT"
  if [ "$tests_passed" -gt 0 ] || [ "$assertions_passed" -gt 0 ]; then
    printf " %s%s passed%s," "$_BASHUNIT_COLOR_PASSED" "$assertions_passed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_skipped" -gt 0 ] || [ "$assertions_skipped" -gt 0 ]; then
    printf " %s%s skipped%s," "$_BASHUNIT_COLOR_SKIPPED" "$assertions_skipped" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_incomplete" -gt 0 ] || [ "$assertions_incomplete" -gt 0 ]; then
    printf " %s%s incomplete%s," "$_BASHUNIT_COLOR_INCOMPLETE" "$assertions_incomplete" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_snapshot" -gt 0 ] || [ "$assertions_snapshot" -gt 0 ]; then
    printf " %s%s snapshot%s," "$_BASHUNIT_COLOR_SNAPSHOT" "$assertions_snapshot" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  if [ "$tests_failed" -gt 0 ] || [ "$assertions_failed" -gt 0 ]; then
    printf " %s%s failed%s," "$_BASHUNIT_COLOR_FAILED" "$assertions_failed" "$_BASHUNIT_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_assertions"

  if [ "$tests_failed" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " Some tests failed " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 1
  fi

  if [ "$tests_risky" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_RISKY" " Some tests risky (no assertions) " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$tests_incomplete" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_INCOMPLETE" " Some tests incomplete " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$tests_skipped" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SKIPPED" " Some tests skipped " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$tests_snapshot" -gt 0 ]; then
    local snapshot_notice=" Some snapshots created "
    if bashunit::env::is_snapshot_update_enabled; then
      snapshot_notice=" Some snapshots updated "
    fi
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SNAPSHOT" "$snapshot_notice" "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 0
  fi

  if [ "$total_tests" -eq 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " No tests found " "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::console_results::print_execution_time
    return 1
  fi

  printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_SUCCESS" " All tests passed " "$_BASHUNIT_COLOR_DEFAULT"
  bashunit::console_results::print_execution_time
  return 0
}

function bashunit::console_results::print_execution_time() {
  if ! bashunit::env::is_total_execution_time_enabled; then
    return
  fi

  local time
  time=$(bashunit::clock::total_runtime_in_milliseconds)
  # Strip decimal portion (integer truncation, Bash 3.0 compatible)
  time="${time%%.*}"
  time="${time:-0}"

  # Reuse the shared ms formatter (Xm Ys / X.XXs / Xms) instead of re-deriving it;
  # this runs once per run, so the command-substitution fork is negligible.
  local formatted
  formatted=$(bashunit::console_results::format_duration "$time")

  printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" \
    "Time taken: ${formatted}"
}

_BASHUNIT_CONSOLE_DURATION_OUT=""

##
# Writes a human-readable duration (Xm Ys / X.XXs / Xms) into
# _BASHUNIT_CONSOLE_DURATION_OUT. Fork-free, so per-test render paths can format
# a duration without a $(...) capture.
# Arguments: $1 - duration in milliseconds
##
function bashunit::console_results::format_duration_to_slot() {
  local duration_ms="$1"

  if [ "$duration_ms" -ge 60000 ]; then
    local time_in_seconds=$((duration_ms / 1000))
    local minutes=$((time_in_seconds / 60))
    local seconds=$((time_in_seconds % 60))
    _BASHUNIT_CONSOLE_DURATION_OUT="${minutes}m ${seconds}s"
  elif [ "$duration_ms" -ge 1000 ]; then
    local integer_part=$((duration_ms / 1000))
    local decimal_part=$(((duration_ms % 1000) / 10))
    # Pad the hundredths by hand: printf would cost a fork on this hot path.
    if [ "$decimal_part" -lt 10 ]; then
      decimal_part="0${decimal_part}"
    fi
    _BASHUNIT_CONSOLE_DURATION_OUT="${integer_part}.${decimal_part}s"
  else
    _BASHUNIT_CONSOLE_DURATION_OUT="${duration_ms}ms"
  fi
}

function bashunit::console_results::format_duration() {
  bashunit::console_results::format_duration_to_slot "$1"
  echo "$_BASHUNIT_CONSOLE_DURATION_OUT"
}

function bashunit::console_results::print_hook_completed() {
  local hook_name="$1"
  local duration_ms="$2"

  if bashunit::env::is_simple_output_enabled; then
    return
  fi

  if bashunit::env::is_failures_only_enabled; then
    return
  fi

  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_tap_output_enabled; then
    return
  fi

  if bashunit::parallel::is_enabled; then
    return
  fi

  local line
  line=$(printf "%s● %s%s" \
    "$_BASHUNIT_COLOR_PASSED" "$hook_name" "$_BASHUNIT_COLOR_DEFAULT")

  local time_display
  time_display=$(bashunit::console_results::format_duration "$duration_ms")

  printf "%s\n" "$(bashunit::str::rpad "$line" "$time_display")"
}

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

##
# Renders a git word-diff of two files, indented, and echoes it. Colorized
# unless --no-color is active. Empty when git is unavailable or files match.
# Shared by the snapshot-failure and multiline assert-failure renderers.
# Arguments: $1 expected file path, $2 actual file path
##
function bashunit::console_results::render_diff() {
  local expected_file=$1
  local actual_file=$2

  if ! bashunit::dependencies::has_git; then
    return 0
  fi

  local color_flag="--color=always"
  if bashunit::env::is_no_color_enabled; then
    color_flag="--color=never"
  fi

  # `git diff` exits non-zero when the files differ; the `|| true` keeps that
  # from tripping `set -e`/`pipefail` under --strict. `tail -n +6` drops git's
  # header lines; `sed` indents the body. `--no-ext-diff` ignores a user's
  # `diff.external`/`GIT_EXTERNAL_DIFF`, which would replace this word-diff.
  git diff --no-index --no-ext-diff --word-diff "$color_flag" \
    "$expected_file" "$actual_file" 2>/dev/null |
    tail -n +6 | sed "s/^/    /" || true
}

##
# Echoes a value's first line, appending an ellipsis when it spans several
# lines. Used to keep the inline quoted value on one line when a diff follows.
##
function bashunit::console_results::first_line_ellipsis() {
  local text=$1
  local first="${text%%$'\n'*}"
  if [ "$first" != "$text" ]; then
    printf '%s…' "$first"
  else
    printf '%s' "$text"
  fi
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
    ${_BASHUNIT_COLOR_FAINT}Expected to match the snapshot${_BASHUNIT_COLOR_DEFAULT}\n" "$function_name")"

  if bashunit::dependencies::has_git; then
    local actual_file="${snapshot_file}.tmp"
    echo "$actual_content" >"$actual_file"

    line="$line$(bashunit::console_results::render_diff "$snapshot_file" "$actual_file")"
    rm "$actual_file"
  else
    line="$line$(bashunit::console_results::snapshot_line_diff \
      "$(cat "$snapshot_file")" "$actual_content")"
  fi

  bashunit::console_results::print_line "failed_snapshot" "$line"
}

##
# Renders a readable line-by-line diff between an expected snapshot and the
# actual content, used as a fallback when git is unavailable. Common lines are
# shown as context, expected-only lines are prefixed with '-' and actual-only
# lines with '+'. Bash 3.0+ compatible (no mapfile, no associative arrays).
# Arguments: $1 expected content, $2 actual content
##
function bashunit::console_results::snapshot_line_diff() {
  local expected=$1
  local actual=$2

  # Explicit empty-array init so referencing the arrays is safe under `set -u`
  # on Bash 4.4+ (Bash 3.x is lenient; newer Bash treats an unset array as unbound).
  # Declare and assign separately: bash 3.0 does not expand a compound array
  # assignment attached to `local`, it stores the literal "()" as element 0.
  local expected_lines actual_lines
  expected_lines=()
  actual_lines=()
  local _line=""
  local i=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    expected_lines[i]=$_line
    i=$((i + 1))
  done <<EOF
$expected
EOF
  local expected_count=$i

  i=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    actual_lines[i]=$_line
    i=$((i + 1))
  done <<EOF
$actual
EOF
  local actual_count=$i

  local max=$expected_count
  if [ "$actual_count" -gt "$max" ]; then
    max=$actual_count
  fi

  local out=""
  i=0
  while [ "$i" -lt "$max" ]; do
    local e="" a="" has_e=0 has_a=0
    if [ "$i" -lt "$expected_count" ]; then
      e=${expected_lines[i]:-}
      has_e=1
    fi
    if [ "$i" -lt "$actual_count" ]; then
      a=${actual_lines[i]:-}
      has_a=1
    fi

    if [ "$has_e" = 1 ] && [ "$has_a" = 1 ] && [ "$e" = "$a" ]; then
      out="$out$(printf "\n    ${_BASHUNIT_COLOR_FAINT}  %s${_BASHUNIT_COLOR_DEFAULT}" "$e")"
    else
      if [ "$has_e" = 1 ]; then
        out="$out$(printf "\n    ${_BASHUNIT_COLOR_FAILED}- %s${_BASHUNIT_COLOR_DEFAULT}" "$e")"
      fi
      if [ "$has_a" = 1 ]; then
        out="$out$(printf "\n    ${_BASHUNIT_COLOR_PASSED}+ %s${_BASHUNIT_COLOR_DEFAULT}" "$a")"
      fi
    fi
    i=$((i + 1))
  done

  printf "%s" "$out"
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

  printf "\n%sStderr from %s%s\n" \
    "$_BASHUNIT_COLOR_SKIPPED" "$test_file" "$_BASHUNIT_COLOR_DEFAULT"
  sed 's/^/|/' "$stderr_file"
}

function bashunit::console_results::print_failing_tests_and_reset() {
  if [ -s "$FAILURES_OUTPUT_PATH" ]; then
    local total_failed
    total_failed=$(bashunit::state::get_tests_failed)

    if bashunit::env::is_simple_output_enabled; then
      printf "\n\n"
    fi

    if [ "$total_failed" -eq 1 ]; then
      echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 failure:${_BASHUNIT_COLOR_DEFAULT}\n"
    else
      echo -e "${_BASHUNIT_COLOR_BOLD}There were $total_failed failures:${_BASHUNIT_COLOR_DEFAULT}\n"
    fi

    sed '${/^$/d;}' "$FAILURES_OUTPUT_PATH" | sed 's/^/|/'
    rm "$FAILURES_OUTPUT_PATH"

    echo ""
  fi
}

##
# Prints the slowest tests recorded during the run, sorted by duration
# descending, limited to BASHUNIT_PROFILE_COUNT entries. Reads the
# tab-separated records appended to PROFILE_OUTPUT_PATH (duration, name, file).
##
function bashunit::console_results::print_profile_and_reset() {
  if [ ! -s "$PROFILE_OUTPUT_PATH" ]; then
    rm -f "$PROFILE_OUTPUT_PATH"
    return
  fi

  local count="${BASHUNIT_PROFILE_COUNT:-10}"

  echo -e "\n${_BASHUNIT_COLOR_BOLD}Slowest tests:${_BASHUNIT_COLOR_DEFAULT}"

  local duration name file formatted
  # -rn on the first (numeric) field; head limits to the requested count.
  while IFS=$'\t' read -r duration name file; do
    formatted=$(bashunit::console_results::format_duration "$duration")
    printf "  %s\t%s (%s)\n" "$formatted" "$name" "$file"
  done < <(sort -t"$(printf '\t')" -k1 -rn "$PROFILE_OUTPUT_PATH" | head -n "$count")

  echo ""

  rm -f "$PROFILE_OUTPUT_PATH"
}

##
# Flushes a deferred summary block (skipped/incomplete/risky): prints the
# "There was 1 <noun>" / "There were N <nouns>" header, then the recorded lines
# from output_path (carriage returns stripped, blank lines dropped, each prefixed
# with "|"), removes the file and prints a trailing blank line. Callers own the
# `[ -s path ]` (and any `is_show_*`) guard so each block keeps its own gate.
# Arguments: $1 output path, $2 total count, $3 singular noun, $4 plural noun
##
function bashunit::console_results::flush_deferred_block() {
  local output_path=$1
  local total=$2
  local singular=$3
  local plural=$4

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  if [ "$total" -eq 1 ]; then
    echo -e "${_BASHUNIT_COLOR_BOLD}There was 1 ${singular}:${_BASHUNIT_COLOR_DEFAULT}\n"
  else
    echo -e "${_BASHUNIT_COLOR_BOLD}There were ${total} ${plural}:${_BASHUNIT_COLOR_DEFAULT}\n"
  fi

  tr -d '\r' <"$output_path" | sed '/^[[:space:]]*$/d' | sed 's/^/|/'
  rm "$output_path"

  echo ""
}

function bashunit::console_results::print_skipped_tests_and_reset() {
  if [ -s "$SKIPPED_OUTPUT_PATH" ] && bashunit::env::is_show_skipped_enabled; then
    bashunit::console_results::flush_deferred_block "$SKIPPED_OUTPUT_PATH" \
      "$(bashunit::state::get_tests_skipped)" "skipped test" "skipped tests"
  fi
}

function bashunit::console_results::print_incomplete_tests_and_reset() {
  if [ -s "$INCOMPLETE_OUTPUT_PATH" ] && bashunit::env::is_show_incomplete_enabled; then
    bashunit::console_results::flush_deferred_block "$INCOMPLETE_OUTPUT_PATH" \
      "$(bashunit::state::get_tests_incomplete)" "incomplete test" "incomplete tests"
  fi
}

function bashunit::console_results::print_risky_tests_and_reset() {
  if [ -s "$RISKY_OUTPUT_PATH" ]; then
    bashunit::console_results::flush_deferred_block "$RISKY_OUTPUT_PATH" \
      "$(bashunit::state::get_tests_risky)" "risky test" "risky tests"
  fi
}

##
# Emit one progress entry for a finished test, in whichever output mode is
# active (verbose line, --simple char, or TAP).
#
# Lived in state.sh until #868. Rendering from the counter module was a layering
# inversion, and it was the sole reason for the state -> parallel call cycle that
# #862 broke; keep it here so state.sh owns counters and the payload only.
# Arguments: $1 - test type, $2 - already formatted line
##
function bashunit::console_results::print_line() {
  # shellcheck disable=SC2034
  local type=$1
  local line=$2

  ((_BASHUNIT_TOTAL_TESTS_COUNT++)) || true

  bashunit::state::add_test_output "[$type]$line"

  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_tap_output_enabled; then
    bashunit::console_results::print_tap_line "$type" "$line"
    return
  fi

  if ! bashunit::env::is_simple_output_enabled; then
    printf "%s\n" "$line"
    return
  fi

  local char
  case "$type" in
  successful) char="." ;;
  failure) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  failed) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  failed_snapshot) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  skipped) char="${_BASHUNIT_COLOR_SKIPPED}S${_BASHUNIT_COLOR_DEFAULT}" ;;
  incomplete) char="${_BASHUNIT_COLOR_INCOMPLETE}I${_BASHUNIT_COLOR_DEFAULT}" ;;
  snapshot) char="${_BASHUNIT_COLOR_SNAPSHOT}N${_BASHUNIT_COLOR_DEFAULT}" ;;
  risky) char="${_BASHUNIT_COLOR_RISKY}R${_BASHUNIT_COLOR_DEFAULT}" ;;
  error) char="${_BASHUNIT_COLOR_FAILED}E${_BASHUNIT_COLOR_DEFAULT}" ;;
  *) char="?" && bashunit::log "warning" "unknown test type '$type'" ;;
  esac

  if bashunit::parallel::is_enabled; then
    printf "%s" "$char"
  else
    if ((_BASHUNIT_TOTAL_TESTS_COUNT % 50 == 0)); then
      printf "%s\n" "$char"
    else
      printf "%s" "$char"
    fi
  fi
}

function bashunit::console_results::print_tap_line() {
  local type=$1
  local line=$2

  local clean_line
  clean_line=$(printf "%s" "$line" | sed 's/\x1B\[[0-9;]*[mK]//g')
  local test_name="${clean_line#*: }"
  test_name="${test_name%%$'\n'*}"
  # Strip trailing whitespace and duration
  test_name=$(printf "%s" "$test_name" | \
    sed 's/[[:space:]]*[0-9][0-9]*m\{0,1\}[[:space:]]*[0-9.]*[ms]*[[:space:]]*$//')

  case "$type" in
  successful)
    printf "ok %d - %s\n" "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  failure | failed | failed_snapshot | error)
    printf "not ok %d - %s\n" "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    local detail_line
    printf "  ---\n"
    while IFS= read -r detail_line; do
      detail_line=$(printf "%s" "$detail_line" | sed 's/\x1B\[[0-9;]*[mK]//g')
      if [ -n "$detail_line" ] \
        && [ "$(echo "$detail_line" | "$GREP" -cF "Failed:" || true)" -eq 0 ] \
        && [ "$(echo "$detail_line" | "$GREP" -cF "Error:" || true)" -eq 0 ]; then
        local trimmed="${detail_line#"${detail_line%%[![:space:]]*}"}"
        printf "  %s\n" "$trimmed"
      fi
    done <<< "$clean_line"
    printf "  ...\n"
    ;;
  skipped)
    local skip_name="${test_name%%   *}"
    local skip_reason="${test_name#"$skip_name"}"
    skip_reason="${skip_reason#"${skip_reason%%[![:space:]]*}"}"
    if [ -n "$skip_reason" ]; then
      printf "ok %d - %s # SKIP %s\n" \
        "$_BASHUNIT_TOTAL_TESTS_COUNT" "$skip_name" "$skip_reason"
    else
      printf "ok %d - %s # SKIP\n" \
        "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    fi
    ;;
  incomplete)
    printf "ok %d - %s # TODO incomplete\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  snapshot)
    printf "ok %d - %s # snapshot\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  risky)
    printf "ok %d - %s # RISKY no assertions\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  *)
    printf "not ok %d - %s\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  esac
}
