#!/usr/bin/env bash

# Cache base64 -w flag support (Alpine needs -w 0, macOS does not support -w).
# Scrape `base64 --help` once and match with a shell `case` instead of piping
# into a `grep` fork — same detection, one fewer fork per cold start.
_bashunit_base64_help="$(base64 --help 2>&1 || true)"
case "$_bashunit_base64_help" in
*-w*) _BASHUNIT_BASE64_WRAP_FLAG=true ;;
*) _BASHUNIT_BASE64_WRAP_FLAG=false ;;
esac
unset _bashunit_base64_help

# Wire sentinel for an empty base64 payload. base64 of "" is "", which gets lost
# in line parsing, so encode_base64 emits this token and both decode sites map it
# back to "". Single source of truth keeps the encode (helpers.sh) and decode
# (helpers.sh, runner.sh) sides byte-identical.
# shellcheck disable=SC2034 # read cross-file in helpers.sh and runner.sh
_BASHUNIT_BASE64_EMPTY_SENTINEL="_BASHUNIT_EMPTY_"

_BASHUNIT_TESTS_PASSED=0
_BASHUNIT_TESTS_FAILED=0
_BASHUNIT_TESTS_SKIPPED=0
_BASHUNIT_TESTS_INCOMPLETE=0
_BASHUNIT_TESTS_SNAPSHOT=0
_BASHUNIT_TESTS_RISKY=0
_BASHUNIT_ASSERTIONS_PASSED=0
_BASHUNIT_ASSERTIONS_FAILED=0
_BASHUNIT_ASSERTIONS_SKIPPED=0
_BASHUNIT_ASSERTIONS_INCOMPLETE=0
_BASHUNIT_ASSERTIONS_SNAPSHOT=0
_BASHUNIT_DUPLICATED_FUNCTION_NAMES=""
_BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""
_BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=false
_BASHUNIT_TEST_OUTPUT=""
_BASHUNIT_TEST_TITLE=""
_BASHUNIT_TEST_EXIT_CODE=0
_BASHUNIT_TEST_HOOK_FAILURE=""
_BASHUNIT_TEST_HOOK_MESSAGE=""
_BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
_BASHUNIT_ASSERTION_FAILED_IN_TEST=0

function bashunit::state::get_tests_passed() {
  echo "$_BASHUNIT_TESTS_PASSED"
}

function bashunit::state::add_tests_passed() {
  ((_BASHUNIT_TESTS_PASSED++)) || true
}

function bashunit::state::get_tests_failed() {
  echo "$_BASHUNIT_TESTS_FAILED"
}

function bashunit::state::add_tests_failed() {
  ((_BASHUNIT_TESTS_FAILED++)) || true
}

function bashunit::state::get_tests_skipped() {
  echo "$_BASHUNIT_TESTS_SKIPPED"
}

function bashunit::state::add_tests_skipped() {
  ((_BASHUNIT_TESTS_SKIPPED++)) || true
}

function bashunit::state::get_tests_incomplete() {
  echo "$_BASHUNIT_TESTS_INCOMPLETE"
}

function bashunit::state::add_tests_incomplete() {
  ((_BASHUNIT_TESTS_INCOMPLETE++)) || true
}

function bashunit::state::get_tests_snapshot() {
  echo "$_BASHUNIT_TESTS_SNAPSHOT"
}

function bashunit::state::add_tests_snapshot() {
  ((_BASHUNIT_TESTS_SNAPSHOT++)) || true
}

function bashunit::state::get_tests_risky() {
  echo "$_BASHUNIT_TESTS_RISKY"
}

function bashunit::state::add_tests_risky() {
  ((_BASHUNIT_TESTS_RISKY++)) || true
}

function bashunit::state::get_assertions_passed() {
  echo "$_BASHUNIT_ASSERTIONS_PASSED"
}

function bashunit::state::add_assertions_passed() {
  # Cheap global test first: the function call only happens while a
  # bashunit::assert_once marker is open, keeping the per-assertion path flat.
  if [ "${_BASHUNIT_ASSERT_ONCE_ACTIVE:-0}" -eq 1 ]; then
    bashunit::assert::once_is_absorbing && return 0
  fi
  ((_BASHUNIT_ASSERTIONS_PASSED++)) || true
}

function bashunit::state::get_assertions_failed() {
  echo "$_BASHUNIT_ASSERTIONS_FAILED"
}

function bashunit::state::add_assertions_failed() {
  ((_BASHUNIT_ASSERTIONS_FAILED++)) || true
}

function bashunit::state::get_assertions_skipped() {
  echo "$_BASHUNIT_ASSERTIONS_SKIPPED"
}

function bashunit::state::add_assertions_skipped() {
  ((_BASHUNIT_ASSERTIONS_SKIPPED++)) || true
}

function bashunit::state::get_assertions_incomplete() {
  echo "$_BASHUNIT_ASSERTIONS_INCOMPLETE"
}

function bashunit::state::add_assertions_incomplete() {
  ((_BASHUNIT_ASSERTIONS_INCOMPLETE++)) || true
}

function bashunit::state::get_assertions_snapshot() {
  echo "$_BASHUNIT_ASSERTIONS_SNAPSHOT"
}

function bashunit::state::add_assertions_snapshot() {
  ((_BASHUNIT_ASSERTIONS_SNAPSHOT++)) || true
}

function bashunit::state::is_duplicated_test_functions_found() {
  echo "$_BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND"
}

function bashunit::state::set_duplicated_test_functions_found() {
  _BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=true
}

function bashunit::state::get_duplicated_function_names() {
  echo "$_BASHUNIT_DUPLICATED_FUNCTION_NAMES"
}

function bashunit::state::set_duplicated_function_names() {
  _BASHUNIT_DUPLICATED_FUNCTION_NAMES="$1"
}

function bashunit::state::get_file_with_duplicated_function_names() {
  echo "$_BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES"
}

function bashunit::state::set_file_with_duplicated_function_names() {
  _BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES="$1"
}

function bashunit::state::add_test_output() {
  _BASHUNIT_TEST_OUTPUT="$_BASHUNIT_TEST_OUTPUT$1"
}

function bashunit::state::set_test_exit_code() {
  _BASHUNIT_TEST_EXIT_CODE="$1"
}

function bashunit::state::set_test_title() {
  _BASHUNIT_TEST_TITLE="$1"
}

function bashunit::state::reset_test_title() {
  _BASHUNIT_TEST_TITLE=""
}

function bashunit::state::set_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME="$1"
}

function bashunit::state::reset_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
}

function bashunit::state::set_test_hook_failure() {
  _BASHUNIT_TEST_HOOK_FAILURE="$1"
}

function bashunit::state::set_test_hook_message() {
  _BASHUNIT_TEST_HOOK_MESSAGE="$1"
}

function bashunit::state::mark_assertion_failed_in_test() {
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=1
}

function bashunit::state::set_duplicated_functions_merged() {
  bashunit::state::set_duplicated_test_functions_found
  bashunit::state::set_file_with_duplicated_function_names "$1"
  bashunit::state::set_duplicated_function_names "$2"
}

function bashunit::state::initialize_assertions_count() {
  _BASHUNIT_ASSERTIONS_PASSED=0
  _BASHUNIT_ASSERTIONS_FAILED=0
  _BASHUNIT_ASSERTIONS_SKIPPED=0
  _BASHUNIT_ASSERTIONS_INCOMPLETE=0
  _BASHUNIT_ASSERTIONS_SNAPSHOT=0
  _BASHUNIT_TEST_OUTPUT=""
  _BASHUNIT_TEST_TITLE=""
  _BASHUNIT_TEST_HOOK_FAILURE=""
  _BASHUNIT_TEST_HOOK_MESSAGE=""
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
  bashunit::assert::once_reset
}

# base64-encodes a field, writing the result into _BASHUNIT_STATE_ENCODED_OUT.
# Empty values (the common case for title/hook message, and output on a passing
# test) encode to an empty field with no base64 fork (#762). base64 of "" is ""
# anyway, so this stays wire-compatible.
_BASHUNIT_STATE_ENCODED_OUT=""
function bashunit::state::encode_field() {
  local value=$1
  if [ -z "$value" ]; then
    _BASHUNIT_STATE_ENCODED_OUT=""
    return
  fi
  if [ "$_BASHUNIT_BASE64_WRAP_FLAG" = true ]; then
    # Alpine requires the -w 0 option to avoid wrapping
    _BASHUNIT_STATE_ENCODED_OUT=$(echo -n "$value" | base64 -w 0)
  else
    _BASHUNIT_STATE_ENCODED_OUT=$(echo -n "$value" | base64)
  fi
}

function bashunit::state::export_subshell_context() {
  local encoded_test_output
  local encoded_test_title
  local encoded_test_hook_message

  bashunit::state::encode_field "$_BASHUNIT_TEST_OUTPUT"
  encoded_test_output=$_BASHUNIT_STATE_ENCODED_OUT
  bashunit::state::encode_field "$_BASHUNIT_TEST_TITLE"
  encoded_test_title=$_BASHUNIT_STATE_ENCODED_OUT
  bashunit::state::encode_field "$_BASHUNIT_TEST_HOOK_MESSAGE"
  encoded_test_hook_message=$_BASHUNIT_STATE_ENCODED_OUT

  # Emit the encoded result payload with `printf` (a builtin) instead of a
  # `cat <<EOF` heredoc: this runs once per test, so avoiding the fork removes
  # one process per test. The `\`-continued string keeps the per-field layout
  # and produces the exact same single line the heredoc did.
  local payload="\
##ASSERTIONS_FAILED=$_BASHUNIT_ASSERTIONS_FAILED\
##ASSERTIONS_PASSED=$_BASHUNIT_ASSERTIONS_PASSED\
##ASSERTIONS_SKIPPED=$_BASHUNIT_ASSERTIONS_SKIPPED\
##ASSERTIONS_INCOMPLETE=$_BASHUNIT_ASSERTIONS_INCOMPLETE\
##ASSERTIONS_SNAPSHOT=$_BASHUNIT_ASSERTIONS_SNAPSHOT\
##TEST_EXIT_CODE=$_BASHUNIT_TEST_EXIT_CODE\
##TEST_HOOK_FAILURE=$_BASHUNIT_TEST_HOOK_FAILURE\
##TEST_HOOK_MESSAGE=$encoded_test_hook_message\
##TEST_TITLE=$encoded_test_title\
##TEST_OUTPUT=$encoded_test_output##"
  printf '%s\n' "$payload"
}

##
# Folds every parallel worker's `.result` payload back into this shell's
# counters and assertion totals.
#
# Lives here rather than in parallel.sh because it decodes the very payload
# `bashunit::state::export_subshell_context` writes: keeping the encoder and the
# decoder in one module removes the parallel.sh <-> state.sh call cycle and stops
# the format from being described in two places.
#
# Arguments: $1 - the run's parallel temp directory
##
function bashunit::state::aggregate_parallel_results() {
  local temp_dir_parallel_test_suite=$1
  local IFS=$' \t\n'

  bashunit::internal_log "aggregate_parallel_results" "dir:$temp_dir_parallel_test_suite"

  local total_failed=0
  local total_passed=0
  local total_skipped=0
  local total_incomplete=0
  local total_snapshot=0

  local script_dir=""
  for script_dir in "$temp_dir_parallel_test_suite"/*; do
    shopt -s nullglob
    # Bash 3.0 compatible: separate declaration and assignment for arrays
    local result_files
    result_files=("$script_dir"/*.result)
    shopt -u nullglob

    if [ ${#result_files[@]} -eq 0 ]; then
      printf "%sNo tests found%s" "$_BASHUNIT_COLOR_SKIPPED" "$_BASHUNIT_COLOR_DEFAULT"
      continue
    fi

    local result_file=""
    for result_file in "${result_files[@]+"${result_files[@]}"}"; do
      local result_line
      result_line=$(<"$result_file")
      result_line="${result_line##*$'\n'}"

      local failed="${result_line##*##ASSERTIONS_FAILED=}"
      failed="${failed%%##*}"
      failed=${failed:-0}

      local passed="${result_line##*##ASSERTIONS_PASSED=}"
      passed="${passed%%##*}"
      passed=${passed:-0}

      local skipped="${result_line##*##ASSERTIONS_SKIPPED=}"
      skipped="${skipped%%##*}"
      skipped=${skipped:-0}

      local incomplete="${result_line##*##ASSERTIONS_INCOMPLETE=}"
      incomplete="${incomplete%%##*}"
      incomplete=${incomplete:-0}

      local snapshot="${result_line##*##ASSERTIONS_SNAPSHOT=}"
      snapshot="${snapshot%%##*}"
      snapshot=${snapshot:-0}

      local exit_code="${result_line##*##TEST_EXIT_CODE=}"
      exit_code="${exit_code%%##*}"
      exit_code=${exit_code:-0}

      # A truncated or non-payload .result line leaves every ##KEY= strip a
      # no-op, so these fields hold arbitrary text. `$(( ))` on such text is a
      # fatal arithmetic syntax error and `[ -gt ]` reports "integer expression
      # expected", so an unreadable result must degrade to zeros rather than
      # abort the aggregation. One `case` over the concatenation, no fork.
      case "$failed$passed$skipped$incomplete$snapshot$exit_code" in
      *[!0-9]*)
        failed=0 passed=0 skipped=0 incomplete=0 snapshot=0
        # An unparseable result is a failed test, not a silently passing one.
        exit_code=1
        bashunit::internal_log "aggregate_parallel_results" "unparseable result file:$result_file"
        ;;
      esac

      # Add to the total counts
      total_failed=$((total_failed + failed))
      total_passed=$((total_passed + passed))
      total_skipped=$((total_skipped + skipped))
      total_incomplete=$((total_incomplete + incomplete))
      total_snapshot=$((total_snapshot + snapshot))

      if [ "${failed:-0}" -gt 0 ]; then
        bashunit::state::add_tests_failed
        continue
      fi

      if [ "${exit_code:-0}" -ne 0 ]; then
        bashunit::state::add_tests_failed
        continue
      fi

      if [ "${snapshot:-0}" -gt 0 ]; then
        bashunit::state::add_tests_snapshot
        continue
      fi

      if [ "${incomplete:-0}" -gt 0 ]; then
        bashunit::state::add_tests_incomplete
        continue
      fi

      if [ "${skipped:-0}" -gt 0 ]; then
        bashunit::state::add_tests_skipped
        continue
      fi

      # Check for risky test (zero assertions, no error)
      local total_for_test=$((failed + passed + skipped + incomplete + snapshot))
      if [ "$total_for_test" -eq 0 ] && [ "${exit_code:-0}" -eq 0 ]; then
        if bashunit::env::is_fail_on_risky_enabled; then
          bashunit::state::add_tests_failed
        else
          bashunit::state::add_tests_risky
        fi
        continue
      fi

      bashunit::state::add_tests_passed
    done
  done

  export _BASHUNIT_ASSERTIONS_FAILED=$total_failed
  export _BASHUNIT_ASSERTIONS_PASSED=$total_passed
  export _BASHUNIT_ASSERTIONS_SKIPPED=$total_skipped
  export _BASHUNIT_ASSERTIONS_INCOMPLETE=$total_incomplete
  export _BASHUNIT_ASSERTIONS_SNAPSHOT=$total_snapshot

  bashunit::internal_log "aggregate_totals" \
    "failed:$total_failed" \
    "passed:$total_passed" \
    "skipped:$total_skipped" \
    "incomplete:$total_incomplete" \
    "snapshot:$total_snapshot"
}

