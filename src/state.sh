#!/bin/bash

_TESTS_PASSED=0
_TESTS_FAILED=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0
_DUPLICATED_TEST_FUNCTIONS_FOUND=false

function State::getTestsPassed() {
  echo "$_TESTS_PASSED"
}

function State::addTestsPassed() {
  ((_TESTS_PASSED++))
}

function State::getTestsFailed() {
  echo "$_TESTS_FAILED"
}

function State::addTestsFailed() {
  ((_TESTS_FAILED++))
}

function State::getAssertionsPassed() {
  echo "$_ASSERTIONS_PASSED"
}

function State::addAssertionsPassed() {
  ((_ASSERTIONS_PASSED++))
}

function State::getAssertionsFailed() {
  echo "$_ASSERTIONS_FAILED"
}

function State::addAssertionsFailed() {
  ((_ASSERTIONS_FAILED++))
}

function State::isDuplicatedTestFunctionsFound() {
  echo "$_DUPLICATED_TEST_FUNCTIONS_FOUND"
}

function State::setDuplicatedTestFunctionsFound() {
  _DUPLICATED_TEST_FUNCTIONS_FOUND=true
}
