#!/bin/bash

_TESTS_PASSED=0
_TESTS_FAILED=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0
_DUPLICATED_TEST_FUNCTIONS_FOUND=false

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

function state::is_duplicated_test_functions_found() {
  echo "$_DUPLICATED_TEST_FUNCTIONS_FOUND"
}

function state::set_duplicated_test_functions_found() {
  _DUPLICATED_TEST_FUNCTIONS_FOUND=true
}

function State::initializeAssertionsCount() {
    _ASSERTIONS_PASSED=0
    _ASSERTIONS_FAILED=0
}

function State::exportAssertionsCount() {
  echo "##ASSERTIONS_FAILED=$_ASSERTIONS_FAILED##ASSERTIONS_PASSED=$_ASSERTIONS_PASSED##"
}
