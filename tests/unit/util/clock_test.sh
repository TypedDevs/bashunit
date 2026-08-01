#!/usr/bin/env bash

__ORIGINAL_OS=""

function set_up_before_script() {
  __ORIGINAL_OS=$_BASHUNIT_OS
}

function set_up() {
  _BASHUNIT_CLOCK_NOW_IMPL=""
}

function tear_down_after_script() {
  export _BASHUNIT_OS=$__ORIGINAL_OS
}

function mock_non_existing_fn() {
  return 127
}

function mock_date_seconds() {
  if [[ "$1" == "+%s%N" ]]; then
    echo "unsupportedN"
  else
    echo "1727768951"
  fi
}

function test_now_with_perl() {
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock date mock_non_existing_fn
  bashunit::mock perl <<<"1720705883457"
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false

  assert_same "1720705883457" "$(bashunit::clock::now)"
}

function test_now_on_linux_unknown() {
  mock_unknown_linux_os
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock date <<<"1720705883457"
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false

  assert_same "1720705883457" "$(bashunit::clock::now)"
}

function test_now_on_linux_alpine() {
  mock_alpine_os
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock perl <<<"1720705883457"
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false

  assert_same "1720705883457" "$(bashunit::clock::now)"
}

function test_now_on_windows_without_with_powershell() {
  mock_windows_os
  bashunit::mock bashunit::dependencies::has_perl mock_false
  bashunit::mock bashunit::dependencies::has_powershell mock_true
  bashunit::mock powershell <<<"1727768183281580800"
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false
  bashunit::mock date mock_non_existing_fn

  assert_same "1727768183281580800" "$(bashunit::clock::now)"
}

function test_now_on_windows_without_without_powershell() {
  mock_windows_os
  bashunit::mock bashunit::dependencies::has_perl mock_false
  bashunit::mock bashunit::dependencies::has_powershell mock_false
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false
  bashunit::mock date <<<"1727768951"

  assert_same "1727768951" "$(bashunit::clock::now)"
}

function test_now_with_date_seconds_fallback() {
  mock_unknown_linux_os
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock date 'mock_date_seconds "$@"'

  assert_same "1727768951000000000" "$(bashunit::clock::now)"
}

function test_now_on_osx_without_perl() {
  if bashunit::check_os::is_windows; then
    bashunit::skip && return
  fi

  mock_macos
  bashunit::mock bashunit::dependencies::has_perl mock_false
  local EPOCHREALTIME="1727708708.326957"
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false

  assert_same "1727708708326957000" "$(bashunit::clock::now)"
}

function test_now_to_slot_shell_branch_computes_from_epochrealtime() {
  local EPOCHREALTIME="1727708708.326957"

  bashunit::clock::now_to_slot

  assert_same "1727708708326957000" "$_BASHUNIT_CLOCK_NOW_OUT"
}

function test_now_to_slot_date_seconds_branch() {
  mock_unknown_linux_os
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock date 'mock_date_seconds "$@"'

  bashunit::clock::now_to_slot

  assert_same "1727768951000000000" "$_BASHUNIT_CLOCK_NOW_OUT"
}

function test_runtime_in_milliseconds_when_not_empty_time() {
  bashunit::mock perl <<<"1720705883457"
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false

  assert_not_empty "$(bashunit::clock::total_runtime_in_milliseconds)"
}

function test_now_prefers_shell_time_over_perl() {
  local EPOCHREALTIME="1234.567890"
  bashunit::mock perl <<<"999999999999"
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false

  assert_same "1234567890000" "$(bashunit::clock::now)"
}

function test_now_handles_shell_time_with_comma_decimal_separator() {
  local EPOCHREALTIME="1234,567890"

  assert_same "1234567890000" "$(bashunit::clock::now)"
}

function test_now_prefers_python_over_node() {
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock date mock_non_existing_fn
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock bashunit::dependencies::has_python mock_true
  bashunit::mock python <<<"777777777777"
  bashunit::mock bashunit::dependencies::has_node mock_true
  bashunit::mock node <<<"888888888888"

  assert_same "777777777777" "$(bashunit::clock::now)"
}

function test_runtime_in_milliseconds_when_empty_time() {
  mock_macos
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock bashunit::clock::shell_time mock_non_existing_fn
  bashunit::mock bashunit::dependencies::has_python mock_false
  bashunit::mock bashunit::dependencies::has_node mock_false
  bashunit::mock date mock_non_existing_fn

  assert_empty "$(bashunit::clock::total_runtime_in_milliseconds)"
}

function test_clock_is_expensive_true_for_interpreter_impls() {
  local impl result=""
  for impl in perl python node powershell; do
    _BASHUNIT_CLOCK_NOW_IMPL="$impl"
    if bashunit::clock::is_expensive; then
      result="$result $impl:yes"
    else
      result="$result $impl:no"
    fi
  done
  assert_same " perl:yes python:yes node:yes powershell:yes" "$result"
}

function test_clock_is_expensive_false_for_native_impls() {
  local impl result=""
  for impl in shell date date-seconds; do
    _BASHUNIT_CLOCK_NOW_IMPL="$impl"
    if bashunit::clock::is_expensive; then
      result="$result $impl:yes"
    else
      result="$result $impl:no"
    fi
  done
  assert_same " shell:no date:no date-seconds:no" "$result"
}
