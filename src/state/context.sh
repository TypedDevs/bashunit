#!/usr/bin/env bash

# Per-test context: output buffer, exit code, title, hook failure, and the per-test reset.

_BASHUNIT_TEST_OUTPUT=""
_BASHUNIT_TEST_TITLE=""
_BASHUNIT_TEST_EXIT_CODE=0
_BASHUNIT_TEST_HOOK_FAILURE=""
_BASHUNIT_TEST_HOOK_MESSAGE=""
_BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
_BASHUNIT_ASSERTION_FAILED_IN_TEST=0


function bashunit::state::add_test_output() {
  _BASHUNIT_TEST_OUTPUT="$_BASHUNIT_TEST_OUTPUT$1"
}


function bashunit::state::set_test_exit_code() {
  _BASHUNIT_TEST_EXIT_CODE="$1"
}


function bashunit::state::set_test_title() {
  _BASHUNIT_TEST_TITLE="$1"
}


function bashunit::state::reset_test_title() {
  _BASHUNIT_TEST_TITLE=""
}


function bashunit::state::set_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME="$1"
}


function bashunit::state::reset_current_test_interpolated_function_name() {
  _BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME=""
}


function bashunit::state::set_test_hook_failure() {
  _BASHUNIT_TEST_HOOK_FAILURE="$1"
}


function bashunit::state::set_test_hook_message() {
  _BASHUNIT_TEST_HOOK_MESSAGE="$1"
}


function bashunit::state::mark_assertion_failed_in_test() {
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=1
}


function bashunit::state::initialize_assertions_count() {
  _BASHUNIT_ASSERTIONS_PASSED=0
  _BASHUNIT_ASSERTIONS_FAILED=0
  _BASHUNIT_ASSERTIONS_SKIPPED=0
  _BASHUNIT_ASSERTIONS_INCOMPLETE=0
  _BASHUNIT_ASSERTIONS_SNAPSHOT=0
  _BASHUNIT_TEST_OUTPUT=""
  _BASHUNIT_TEST_TITLE=""
  _BASHUNIT_TEST_HOOK_FAILURE=""
  _BASHUNIT_TEST_HOOK_MESSAGE=""
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
  bashunit::assert::once_reset
}

# base64-encodes a field, writing the result into _BASHUNIT_STATE_ENCODED_OUT.
# Empty values (the common case for title/hook message, and output on a passing
# test) encode to an empty field with no base64 fork (#762). base64 of "" is ""
# anyway, so this stays wire-compatible.
_BASHUNIT_STATE_ENCODED_OUT=""
