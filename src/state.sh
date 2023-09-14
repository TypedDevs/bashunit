#!/bin/bash

_TESTS_PASSED=0
_TESTS_FAILED=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0

function getTestsPassed() {
  echo "$_TESTS_PASSED"
}

function addTestsPassed() {
  ((_TESTS_PASSED++))
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

