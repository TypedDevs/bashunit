#!/usr/bin/env bash

_TESTS_PASSED=0
_TESTS_FAILED=0
_TESTS_SKIPPED=0
_TESTS_INCOMPLETE=0
_TESTS_SNAPSHOT=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0
_ASSERTIONS_SKIPPED=0
_ASSERTIONS_INCOMPLETE=0
_ASSERTIONS_SNAPSHOT=0
_DUPLICATED_FUNCTION_NAMES=""
_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""
_DUPLICATED_TEST_FUNCTIONS_FOUND=false
_TEST_OUTPUT=""
_TEST_TITLE=""
_TEST_EXIT_CODE=0
_TEST_HOOK_FAILURE=""
_TEST_HOOK_MESSAGE=""
_CURRENT_TEST_INTERPOLATED_NAME=""
_ASSERTION_FAILED_IN_TEST=false

function state::get_tests_passed() {
  echo "$_TESTS_PASSED"
}

function state::add_tests_passed() {
  ((_TESTS_PASSED++)) || true
}

function state::get_tests_failed() {
  echo "$_TESTS_FAILED"
}

function state::add_tests_failed() {
  ((_TESTS_FAILED++)) || true
}

function state::get_tests_skipped() {
  echo "$_TESTS_SKIPPED"
}

function state::add_tests_skipped() {
  ((_TESTS_SKIPPED++)) || true
}

function state::get_tests_incomplete() {
  echo "$_TESTS_INCOMPLETE"
}

function state::add_tests_incomplete() {
  ((_TESTS_INCOMPLETE++)) || true
}

function state::get_tests_snapshot() {
  echo "$_TESTS_SNAPSHOT"
}

function state::add_tests_snapshot() {
  ((_TESTS_SNAPSHOT++)) || true
}

function state::get_assertions_passed() {
  echo "$_ASSERTIONS_PASSED"
}

function state::add_assertions_passed() {
  ((_ASSERTIONS_PASSED++)) || true
}

function state::get_assertions_failed() {
  echo "$_ASSERTIONS_FAILED"
}

function state::add_assertions_failed() {
  ((_ASSERTIONS_FAILED++)) || true
}

function state::get_assertions_skipped() {
  echo "$_ASSERTIONS_SKIPPED"
}

function state::add_assertions_skipped() {
  ((_ASSERTIONS_SKIPPED++)) || true
}

function state::get_assertions_incomplete() {
  echo "$_ASSERTIONS_INCOMPLETE"
}

function state::add_assertions_incomplete() {
  ((_ASSERTIONS_INCOMPLETE++)) || true
}

function state::get_assertions_snapshot() {
  echo "$_ASSERTIONS_SNAPSHOT"
}

function state::add_assertions_snapshot() {
  ((_ASSERTIONS_SNAPSHOT++)) || true
}

function state::is_duplicated_test_functions_found() {
  echo "$_DUPLICATED_TEST_FUNCTIONS_FOUND"
}

function state::set_duplicated_test_functions_found() {
  _DUPLICATED_TEST_FUNCTIONS_FOUND=true
}

function state::get_duplicated_function_names() {
  echo "$_DUPLICATED_FUNCTION_NAMES"
}

function state::set_duplicated_function_names() {
  _DUPLICATED_FUNCTION_NAMES="$1"
}

function state::get_file_with_duplicated_function_names() {
  echo "$_FILE_WITH_DUPLICATED_FUNCTION_NAMES"
}

function state::set_file_with_duplicated_function_names() {
  _FILE_WITH_DUPLICATED_FUNCTION_NAMES="$1"
}

function state::add_test_output() {
  _TEST_OUTPUT+="$1"
}

function state::get_test_exit_code() {
  echo "$_TEST_EXIT_CODE"
}

function state::set_test_exit_code() {
  _TEST_EXIT_CODE="$1"
}

function state::get_test_title() {
  echo "$_TEST_TITLE"
}

function state::set_test_title() {
  _TEST_TITLE="$1"
}

function state::reset_test_title() {
  _TEST_TITLE=""
}

function state::get_current_test_interpolated_function_name() {
  echo "$_CURRENT_TEST_INTERPOLATED_NAME"
}

function state::set_current_test_interpolated_function_name() {
  _CURRENT_TEST_INTERPOLATED_NAME="$1"
}

function state::reset_current_test_interpolated_function_name() {
  _CURRENT_TEST_INTERPOLATED_NAME=""
}

function state::get_test_hook_failure() {
  echo "$_TEST_HOOK_FAILURE"
}

function state::set_test_hook_failure() {
  _TEST_HOOK_FAILURE="$1"
}

function state::reset_test_hook_failure() {
  _TEST_HOOK_FAILURE=""
}

function state::get_test_hook_message() {
  echo "$_TEST_HOOK_MESSAGE"
}

function state::set_test_hook_message() {
  _TEST_HOOK_MESSAGE="$1"
}

function state::reset_test_hook_message() {
  _TEST_HOOK_MESSAGE=""
}

function state::is_assertion_failed_in_test() {
  [[ "$_ASSERTION_FAILED_IN_TEST" == "true" ]]
}

function state::mark_assertion_failed_in_test() {
  _ASSERTION_FAILED_IN_TEST=true
}

function state::reset_assertion_failed_in_test() {
  _ASSERTION_FAILED_IN_TEST=false
}

function state::set_duplicated_functions_merged() {
  state::set_duplicated_test_functions_found
  state::set_file_with_duplicated_function_names "$1"
  state::set_duplicated_function_names "$2"
}

function state::initialize_assertions_count() {
    _ASSERTIONS_PASSED=0
    _ASSERTIONS_FAILED=0
    _ASSERTIONS_SKIPPED=0
    _ASSERTIONS_INCOMPLETE=0
    _ASSERTIONS_SNAPSHOT=0
    _TEST_OUTPUT=""
    _TEST_TITLE=""
    _TEST_HOOK_FAILURE=""
    _TEST_HOOK_MESSAGE=""
    _ASSERTION_FAILED_IN_TEST=false
}

function state::export_subshell_context() {
  local encoded_test_output
  local encoded_test_title

  local encoded_test_hook_message

  if base64 --help 2>&1 | grep -q -- "-w"; then
    # Alpine requires the -w 0 option to avoid wrapping
    encoded_test_output=$(echo -n "$_TEST_OUTPUT" | base64 -w 0)
    encoded_test_title=$(echo -n "$_TEST_TITLE" | base64 -w 0)
    encoded_test_hook_message=$(echo -n "$_TEST_HOOK_MESSAGE" | base64 -w 0)
  else
    # macOS and others: default base64 without wrapping
    encoded_test_output=$(echo -n "$_TEST_OUTPUT" | base64)
    encoded_test_title=$(echo -n "$_TEST_TITLE" | base64)
    encoded_test_hook_message=$(echo -n "$_TEST_HOOK_MESSAGE" | base64)
  fi

  cat <<EOF
##ASSERTIONS_FAILED=$_ASSERTIONS_FAILED\
##ASSERTIONS_PASSED=$_ASSERTIONS_PASSED\
##ASSERTIONS_SKIPPED=$_ASSERTIONS_SKIPPED\
##ASSERTIONS_INCOMPLETE=$_ASSERTIONS_INCOMPLETE\
##ASSERTIONS_SNAPSHOT=$_ASSERTIONS_SNAPSHOT\
##TEST_EXIT_CODE=$_TEST_EXIT_CODE\
##TEST_HOOK_FAILURE=$_TEST_HOOK_FAILURE\
##TEST_HOOK_MESSAGE=$encoded_test_hook_message\
##TEST_TITLE=$encoded_test_title\
##TEST_OUTPUT=$encoded_test_output\
##
EOF
}

function state::calculate_total_assertions() {
  local input="$1"
  local total=0

  local numbers
  numbers=$(echo "$input" | grep -oE '##ASSERTIONS_\w+=[0-9]+' | grep -oE '[0-9]+')

  for number in $numbers; do
    ((total += number))
  done

  echo $total
}

function state::print_line() {
  # shellcheck disable=SC2034
  local type=$1
  local line=$2

  ((_TOTAL_TESTS_COUNT++)) || true

  state::add_test_output "[$type]$line"

  if ! env::is_simple_output_enabled; then
    printf "%s\n" "$line"
    return
  fi

  local char
  case "$type" in
    successful)       char="." ;;
    failure)          char="${_COLOR_FAILED}F${_COLOR_DEFAULT}" ;;
    failed)           char="${_COLOR_FAILED}F${_COLOR_DEFAULT}" ;;
    failed_snapshot)  char="${_COLOR_FAILED}F${_COLOR_DEFAULT}" ;;
    skipped)          char="${_COLOR_SKIPPED}S${_COLOR_DEFAULT}" ;;
    incomplete)       char="${_COLOR_INCOMPLETE}I${_COLOR_DEFAULT}" ;;
    snapshot)         char="${_COLOR_SNAPSHOT}N${_COLOR_DEFAULT}" ;;
    error)            char="${_COLOR_FAILED}E${_COLOR_DEFAULT}" ;;
    *)                char="?" && log "warning" "unknown test type '$type'" ;;
  esac

  if parallel::is_enabled; then
      printf "%s" "$char"
  else
    if (( _TOTAL_TESTS_COUNT % 50 == 0 )); then
      printf "%s\n" "$char"
    else
      printf "%s" "$char"
    fi
  fi
}
