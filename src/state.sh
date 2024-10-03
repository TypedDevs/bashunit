#!/bin/bash

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
}

function state::export_subshell_context() {
  local encoded_test_output
  if base64 --help 2>&1 | grep -q -- "-w"; then
    # Alpine needs -w 0 to avoid line wrapping
    encoded_test_output=$(echo -n "$_TEST_OUTPUT" | base64 -w 0)
  else
    # macOS and others don't need -w 0
    encoded_test_output=$(echo -n "$_TEST_OUTPUT" | base64)
  fi

  echo "##ASSERTIONS_FAILED=$_ASSERTIONS_FAILED\
##ASSERTIONS_PASSED=$_ASSERTIONS_PASSED\
##ASSERTIONS_SKIPPED=$_ASSERTIONS_SKIPPED\
##ASSERTIONS_INCOMPLETE=$_ASSERTIONS_INCOMPLETE\
##ASSERTIONS_SNAPSHOT=$_ASSERTIONS_SNAPSHOT\
##TEST_OUTPUT=$encoded_test_output\
##"
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

  if ! env::is_simple_output_enabled ; then
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
    *)                char="?" ;;
  esac

  if (( _TOTAL_TESTS_COUNT % 50 == 0 )); then
    printf "%s\n" "$char"
  else
    printf "%s" "$char"
  fi
}
