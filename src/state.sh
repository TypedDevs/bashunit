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

function State::addTestsFailed() {
  ((_TESTS_FAILED++)) || true
}

function State::getAssertionsPassed() {
  echo "$_ASSERTIONS_PASSED"
}

function State::addAssertionsPassed() {
  ((_ASSERTIONS_PASSED++)) || true
}

function State::getAssertionsFailed() {
  echo "$_ASSERTIONS_FAILED"
}

function State::addAssertionsFailed() {
  ((_ASSERTIONS_FAILED++)) || true
}

function State::isDuplicatedTestFunctionsFound() {
  echo "$_DUPLICATED_TEST_FUNCTIONS_FOUND"
}

function State::setDuplicatedTestFunctionsFound() {
  _DUPLICATED_TEST_FUNCTIONS_FOUND=true
}

function State::initializeAssertionsCount() {
    _ASSERTIONS_PASSED=0
    _ASSERTIONS_FAILED=0
}

function State::exportAssertionsCount() {
  echo "##ASSERTIONS_FAILED=$_ASSERTIONS_FAILED##ASSERTIONS_PASSED=$_ASSERTIONS_PASSED##"
}
