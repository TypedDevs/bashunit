#!/bin/bash

function assert_file_exists() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -f "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  state::add_assertions_passed
}

function assert_file_not_exists() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ -f "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to not exist but" "the file exists"
    return
  fi

  state::add_assertions_passed
}

function assert_is_file() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -f "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be a file" "but is not a file"
    return
  fi

  state::add_assertions_passed
}

function assert_is_file_empty() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ -s "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  state::add_assertions_passed
}

function assert_files_equals() {
  local expected="$1"
  local actual="$2"

  if [[ "$(diff -u "$expected" "$actual")" != '' ]] ; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed

    console_results::print_failed_test "${label}" "${expected}" "Compared" "${actual}" \
        "Diff" "$(diff -u "$expected" "$actual" | sed '1,2d')"
    return
  fi

  state::add_assertions_passed
}

function assert_files_not_equals() {
  local expected="$1"
  local actual="$2"

  if [[ "$(diff -u "$expected" "$actual")" == '' ]] ; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed

    console_results::print_failed_test "${label}" "${expected}" "Compared" "${actual}" \
        "Diff" "Files are equals"
    return
  fi

  state::add_assertions_passed
}

function assert_file_contains() {
  local file="$1"
  local string="$2"

  if ! grep -q "$string" "$file"; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed

    console_results::print_failed_test "${label}" "${file}" "to contain" "${string}"
    return
  fi

  state::add_assertions_passed
}

function assert_file_not_contains() {
  local file="$1"
  local string="$2"

  if grep -q "$string" "$file"; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed

    console_results::print_failed_test "${label}" "${file}" "to not contain" "${string}"
    return
  fi

  state::add_assertions_passed
}
