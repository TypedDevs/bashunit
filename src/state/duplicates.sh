#!/usr/bin/env bash

# Duplicate test-function detection state.

_BASHUNIT_DUPLICATED_FUNCTION_NAMES=""
_BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""
_BASHUNIT_DUPLICATED_FUNCTION_DETAILS=""
_BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=false

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


function bashunit::state::get_duplicated_function_details() {
  echo "$_BASHUNIT_DUPLICATED_FUNCTION_DETAILS"
}


function bashunit::state::set_duplicated_function_details() {
  _BASHUNIT_DUPLICATED_FUNCTION_DETAILS="$1"
}


# Arguments: $1 - file, $2 - duplicate names, $3 - the same names with the line
# numbers of every definition (optional; the summary falls back to $2)
function bashunit::state::set_duplicated_functions_merged() {
  bashunit::state::set_duplicated_test_functions_found
  bashunit::state::set_file_with_duplicated_function_names "$1"
  bashunit::state::set_duplicated_function_names "$2"
  bashunit::state::set_duplicated_function_details "${3:-}"
}

