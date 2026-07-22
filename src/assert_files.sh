#!/usr/bin/env bash

function assert_file_exists() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ ! -f "$expected" ]; then
    bashunit::assert::label_to_slot "${3:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_file_not_exists() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ -f "$expected" ]; then
    bashunit::assert::label_to_slot "${3:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to not exist but" "the file exists"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ ! -f "$expected" ]; then
    bashunit::assert::label_to_slot "${3:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be a file" "but is not a file"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_file_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [ -s "$expected" ]; then
    bashunit::assert::label_to_slot "${3:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_files_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [ "$(diff -u "$expected" "$actual")" != '' ]; then
    bashunit::assert::label_to_slot
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed

    bashunit::console_results::print_failed_test "${label}" "${expected}" "Compared" "${actual}" \
      "Diff" "$(diff -u "$expected" "$actual" | sed '1,2d')"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_files_not_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [ "$(diff -u "$expected" "$actual")" = '' ]; then
    bashunit::assert::label_to_slot
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed

    bashunit::console_results::print_failed_test "${label}" "${expected}" "Compared" "${actual}" \
      "Diff" "Files are equals"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_file_contains() {
  bashunit::assert::should_skip && return 0

  local file="$1"
  local string="$2"

  if ! grep -F -q "$string" "$file"; then
    bashunit::assert::label_to_slot
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed

    bashunit::console_results::print_failed_test "${label}" "${file}" "to contain" "${string}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_file_not_contains() {
  bashunit::assert::should_skip && return 0

  local file="$1"
  local string="$2"

  if grep -q "$string" "$file"; then
    bashunit::assert::label_to_slot
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed

    bashunit::console_results::print_failed_test "${label}" "${file}" "to not contain" "${string}"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Normalizes an octal file mode to its decimal value, dropping leading zeros
# (so "0755" and "755" compare equal). Echoes nothing on invalid octal input.
# Arguments: $1 - octal mode string
##
function bashunit::assert::_octal_to_decimal() {
  local mode="$1"
  case "$mode" in
  '' | *[!0-7]*) return 1 ;;
  esac
  printf '%d' "$((8#$mode))"
}

##
# Asserts a file has the expected octal permission mode (e.g. "644", "0755").
# Arguments: $1 - expected octal mode, $2 - file path
##
function assert_file_permissions() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local file="$2"
  bashunit::assert::label_to_slot
  local label=$_BASHUNIT_ASSERT_LABEL_OUT

  if [ ! -e "$file" ]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${file}" "to have permissions ${expected}" "but the file does not exist"
    return
  fi

  local actual
  actual="$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null)"

  local expected_dec actual_dec
  expected_dec="$(bashunit::assert::_octal_to_decimal "$expected")"
  actual_dec="$(bashunit::assert::_octal_to_decimal "$actual")"

  if [ "$expected_dec" != "$actual_dec" ]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${file}" "to have permissions ${expected}" "but got ${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}
