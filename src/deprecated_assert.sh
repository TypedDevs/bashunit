#!/bin/bash

# Deprecated: Please use assert_equals instead.
function assertEquals() {
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_equals "$1" "$2" "$label"
}

# Deprecated: Please use assert_empty instead.
function assertEmpty() {
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_empty "$1" "$label"
}

# Deprecated: Please use assert_not_empty instead.
function assertNotEmpty() {
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_not_empty "$1" "$label"
}

# Deprecated: Please use assert_not_equals instead.
function assertNotEquals() {
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_not_equals "$1" "$2" "$label"
}

# Deprecated: Please use assert_contains instead.
function assertContains() {
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_contains "$1" "$2" "$label"
}

# Deprecated: Please use assert_not_contains instead.
function assertNotContains() {
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_not_contains "$1" "$2" "$label"
}

# Deprecated: Please use assert_matches instead.
function assertMatches() {
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_matches "$1" "$2" "$label"
}

# Deprecated: Please use assert_not_matches instead.
function assertNotMatches() {
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_not_matches "$1" "$2" "$label"
}

# Deprecated: Please use assert_exit_code instead.
function assertExitCode() {
  local actual_exit_code=$?
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_exit_code "$1" "$label" "$actual_exit_code"
}

# Deprecated: Please use assert_successful_code instead.
function assertSuccessfulCode() {
  local actual_exit_code=$?
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_successful_code "$1" "$label" "$actual_exit_code"
}

# Deprecated: Please use assert_general_error instead.
function assertGeneralError() {
  local actual_exit_code=$?
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_general_error "$1" "$label" "$actual_exit_code"
}

# Deprecated: Please use assert_command_not_found instead.
function assertCommandNotFound() {
  local actual_exit_code=$?
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  assert_command_not_found "{command}" "$label" "$actual_exit_code"
}

# Deprecated: Please use assert_array_contains instead.
function assertArrayContains() {
  assert_array_contains "$1" "${@:2}"
}

# Deprecated: Please use assert_array_not_contains instead.
function assertArrayNotContains() {
  assert_array_not_contains "$1" "${@:1}"
}
