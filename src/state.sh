#!/bin/bash

_TESTS_PASSED=0
_TESTS_FAILED=0
_TESTS_SKIPPED=0
_TESTS_INCOMPLETE=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0
_ASSERTIONS_SKIPPED=0
_ASSERTIONS_INCOMPLETE=0
_DUPLICATED_TEST_FUNCTIONS_FOUND=false
_DUPLICATED_FUNCTION_NAMES=""
_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""

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

function state::initialize_assertions_count() {
    _ASSERTIONS_PASSED=0
    _ASSERTIONS_FAILED=0
    _ASSERTIONS_SKIPPED=0
    _ASSERTIONS_INCOMPLETE=0
}

function state::export_assertions_count() {
  echo "##ASSERTIONS_FAILED=$_ASSERTIONS_FAILED\
##ASSERTIONS_PASSED=$_ASSERTIONS_PASSED\
##ASSERTIONS_SKIPPED=$_ASSERTIONS_SKIPPED\
##ASSERTIONS_INCOMPLETE=$_ASSERTIONS_INCOMPLETE\
##"
}
