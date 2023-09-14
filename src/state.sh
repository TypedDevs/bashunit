#!/bin/bash

_LOCK_FILE="/dev/shm/_LOCK_FILE"
_TESTS_PASSED="/dev/shm/_TESTS_PASSED"
_TESTS_FAILED=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0

echo 0 > "$_TESTS_PASSED"

function getTestsPassed() {
  local _tests_passed
  _tests_passed=$(cat $_TESTS_PASSED)

  echo "$_tests_passed"
}

function addTestsPassed() {
  (
    flock -x 200

    local _tests_passed
    _tests_passed=$(getTestsPassed)

    echo $((_tests_passed + 1)) > "$_TESTS_PASSED"
  ) 200>"$_LOCK_FILE"
}

function getTestsFailed() {
  echo "$_TESTS_FAILED"
}

function addTestsFailed() {
  ((_TESTS_FAILED++))
}

function getAssertionsPassed() {
  echo "$_ASSERTIONS_PASSED"
}

function addAssertionsPassed() {
  ((_ASSERTIONS_PASSED++))
}

function getAssertionsFailed() {
  echo "$_ASSERTIONS_FAILED"
}

function addAssertionsFailed() {
  ((_ASSERTIONS_FAILED++))
}

