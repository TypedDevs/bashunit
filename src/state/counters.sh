#!/usr/bin/env bash

# Test and assertion tallies: the _BASHUNIT_TESTS_*/_ASSERTIONS_* globals and their get/add accessors.

_BASHUNIT_TESTS_PASSED=0
_BASHUNIT_TESTS_FAILED=0
_BASHUNIT_TESTS_SKIPPED=0
_BASHUNIT_TESTS_INCOMPLETE=0
_BASHUNIT_TESTS_SNAPSHOT=0
_BASHUNIT_TESTS_RISKY=0
# Flaky is a facet of passed, not a seventh outcome: it counts tests already
# tallied in _BASHUNIT_TESTS_PASSED, so it must never be added to the total.
_BASHUNIT_TESTS_FLAKY=0
_BASHUNIT_ASSERTIONS_PASSED=0
_BASHUNIT_ASSERTIONS_FAILED=0
_BASHUNIT_ASSERTIONS_SKIPPED=0
_BASHUNIT_ASSERTIONS_INCOMPLETE=0
_BASHUNIT_ASSERTIONS_SNAPSHOT=0

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


function bashunit::state::get_tests_risky() {
  echo "$_BASHUNIT_TESTS_RISKY"
}


function bashunit::state::add_tests_risky() {
  ((_BASHUNIT_TESTS_RISKY++)) || true
}


function bashunit::state::get_tests_flaky() {
  echo "$_BASHUNIT_TESTS_FLAKY"
}


function bashunit::state::add_tests_flaky() {
  ((_BASHUNIT_TESTS_FLAKY++)) || true
}


function bashunit::state::get_assertions_passed() {
  echo "$_BASHUNIT_ASSERTIONS_PASSED"
}


function bashunit::state::add_assertions_passed() {
  # Cheap global test first: the function call only happens while a
  # bashunit::assert_once marker is open, keeping the per-assertion path flat.
  if [ "${_BASHUNIT_ASSERT_ONCE_ACTIVE:-0}" -eq 1 ]; then
    bashunit::assert::once_is_absorbing && return 0
  fi
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


