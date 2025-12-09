#!/usr/bin/env bash

_BASHUNIT_TESTS_PASSED=0
_BASHUNIT_TESTS_FAILED=0
_BASHUNIT_TESTS_SKIPPED=0
_BASHUNIT_TESTS_INCOMPLETE=0
_BASHUNIT_TESTS_SNAPSHOT=0
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

function bashunit::state::get_assertions_passed() {
  echo "$_BASHUNIT_ASSERTIONS_PASSED"
}

function bashunit::state::add_assertions_passed() {
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
  _BASHUNIT_TEST_OUTPUT+="$1"
}

function bashunit::state::get_test_exit_code() {
  echo "$_BASHUNIT_TEST_EXIT_CODE"
}

function bashunit::state::set_test_exit_code() {
  _BASHUNIT_TEST_EXIT_CODE="$1"
}

function bashunit::state::get_test_title() {
  echo "$_BASHUNIT_TEST_TITLE"
}

function bashunit::state::set_test_title() {
  _BASHUNIT_TEST_TITLE="$1"
}

function bashunit::state::reset_test_title() {
  _BASHUNIT_TEST_TITLE=""
}

function bashunit::state::get_current_test_interpolated_function_name() {
  echo "$_BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME"
}

function bashunit::state::set_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME="$1"
}

function bashunit::state::reset_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
}

function bashunit::state::get_test_hook_failure() {
  echo "$_BASHUNIT_TEST_HOOK_FAILURE"
}

function bashunit::state::set_test_hook_failure() {
  _BASHUNIT_TEST_HOOK_FAILURE="$1"
}

function bashunit::state::reset_test_hook_failure() {
  _BASHUNIT_TEST_HOOK_FAILURE=""
}

function bashunit::state::get_test_hook_message() {
  echo "$_BASHUNIT_TEST_HOOK_MESSAGE"
}

function bashunit::state::set_test_hook_message() {
  _BASHUNIT_TEST_HOOK_MESSAGE="$1"
}

function bashunit::state::reset_test_hook_message() {
  _BASHUNIT_TEST_HOOK_MESSAGE=""
}

function bashunit::state::is_assertion_failed_in_test() {
  (( _BASHUNIT_ASSERTION_FAILED_IN_TEST ))
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
}

function bashunit::state::export_subshell_context() {
  local encoded_test_output
  local encoded_test_title

  local encoded_test_hook_message

  if base64 --help 2>&1 | grep -q -- "-w"; then
    # Alpine requires the -w 0 option to avoid wrapping
    encoded_test_output=$(echo -n "$_BASHUNIT_TEST_OUTPUT" | base64 -w 0)
    encoded_test_title=$(echo -n "$_BASHUNIT_TEST_TITLE" | base64 -w 0)
    encoded_test_hook_message=$(echo -n "$_BASHUNIT_TEST_HOOK_MESSAGE" | base64 -w 0)
  else
    # macOS and others: default base64 without wrapping
    encoded_test_output=$(echo -n "$_BASHUNIT_TEST_OUTPUT" | base64)
    encoded_test_title=$(echo -n "$_BASHUNIT_TEST_TITLE" | base64)
    encoded_test_hook_message=$(echo -n "$_BASHUNIT_TEST_HOOK_MESSAGE" | base64)
  fi

  cat <<EOF
##ASSERTIONS_FAILED=$_BASHUNIT_ASSERTIONS_FAILED\
##ASSERTIONS_PASSED=$_BASHUNIT_ASSERTIONS_PASSED\
##ASSERTIONS_SKIPPED=$_BASHUNIT_ASSERTIONS_SKIPPED\
##ASSERTIONS_INCOMPLETE=$_BASHUNIT_ASSERTIONS_INCOMPLETE\
##ASSERTIONS_SNAPSHOT=$_BASHUNIT_ASSERTIONS_SNAPSHOT\
##TEST_EXIT_CODE=$_BASHUNIT_TEST_EXIT_CODE\
##TEST_HOOK_FAILURE=$_BASHUNIT_TEST_HOOK_FAILURE\
##TEST_HOOK_MESSAGE=$encoded_test_hook_message\
##TEST_TITLE=$encoded_test_title\
##TEST_OUTPUT=$encoded_test_output\
##
EOF
}

function bashunit::state::calculate_total_assertions() {
  local input="$1"
  local total=0

  local numbers
  numbers=$(echo "$input" | grep -oE '##ASSERTIONS_\w+=[0-9]+' | grep -oE '[0-9]+')

  for number in $numbers; do
    ((total += number))
  done

  echo $total
}

function bashunit::state::print_line() {
  # shellcheck disable=SC2034
  local type=$1
  local line=$2

  ((_BASHUNIT_TOTAL_TESTS_COUNT++)) || true

  bashunit::state::add_test_output "[$type]$line"

  if ! bashunit::env::is_show_progress_enabled; then
    return
  fi

  if ! bashunit::env::is_simple_output_enabled; then
    printf "%s\n" "$line"
    return
  fi

  local char
  case "$type" in
    successful)       char="." ;;
    failure)          char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
    failed)           char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
    failed_snapshot)  char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
    skipped)          char="${_BASHUNIT_COLOR_SKIPPED}S${_BASHUNIT_COLOR_DEFAULT}" ;;
    incomplete)       char="${_BASHUNIT_COLOR_INCOMPLETE}I${_BASHUNIT_COLOR_DEFAULT}" ;;
    snapshot)         char="${_BASHUNIT_COLOR_SNAPSHOT}N${_BASHUNIT_COLOR_DEFAULT}" ;;
    error)            char="${_BASHUNIT_COLOR_FAILED}E${_BASHUNIT_COLOR_DEFAULT}" ;;
    *)                char="?" && bashunit::log "warning" "unknown test type '$type'" ;;
  esac

  if bashunit::parallel::is_enabled; then
      printf "%s" "$char"
  else
    if (( _BASHUNIT_TOTAL_TESTS_COUNT % 50 == 0 )); then
      printf "%s\n" "$char"
    else
      printf "%s" "$char"
    fi
  fi
}
