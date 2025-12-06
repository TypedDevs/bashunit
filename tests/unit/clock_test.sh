#!/usr/bin/env bash

__ORIGINAL_OS=""

function set_up_before_script() {
  __ORIGINAL_OS=$_OS
}

function tear_down_after_script() {
  export _OS=$__ORIGINAL_OS
}

function mock_non_existing_fn() {
  return 127;
}

function mock_date_seconds() {
  if [[ "$1" == "+%s%N" ]]; then
    echo "unsupportedN"
  else
    echo "1727768951"
  fi
}

function test_now_with_perl() {
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock perl <<< "1720705883457"
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_unknown() {
  mock_unknown_linux_os
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock date <<< "1720705883457"
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_alpine() {
  mock_alpine_os
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock perl <<< "1720705883457"
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_windows_without_with_powershell() {
  mock_windows_os
  bashunit::mock dependencies::has_perl mock_false
  bashunit::mock dependencies::has_powershell mock_true
  bashunit::mock powershell <<< "1727768183281580800"
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "1727768183281580800" "$(clock::now)"
}

function test_now_on_windows_without_without_powershell() {
  mock_windows_os
  bashunit::mock dependencies::has_perl mock_false
  bashunit::mock dependencies::has_powershell mock_false
  bashunit::mock date <<< "1727768951"
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "1727768951" "$(clock::now)"
}

function test_now_with_date_seconds_fallback() {
  mock_unknown_linux_os
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock date 'mock_date_seconds "$@"'

  assert_same "1727768951000000000" "$(clock::now)"
}

function test_now_on_osx_without_perl() {
  if check_os::is_windows; then
    bashunit::skip && return
  fi

  mock_macos
  bashunit::mock dependencies::has_perl mock_false
  bashunit::mock clock::shell_time <<< "1727708708.326957"
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "1727708708326957000" "$(clock::now)"
}

function test_runtime_in_milliseconds_when_not_empty_time() {
  bashunit::mock perl <<< "1720705883457"
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_not_empty "$(clock::total_runtime_in_milliseconds)"
}

function test_now_prefers_perl_over_shell_time() {
  bashunit::mock clock::shell_time <<< "1234.0"
  bashunit::mock perl <<< "999999999999"
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false

  assert_same "999999999999" "$(clock::now)"
}

function test_now_prefers_python_over_node() {
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock dependencies::has_python mock_true
  bashunit::mock python <<< "777777777777"
  bashunit::mock dependencies::has_node mock_true
  bashunit::mock node <<< "888888888888"

  assert_same "777777777777" "$(clock::now)"
}

function test_runtime_in_milliseconds_when_empty_time() {
  mock_macos
  bashunit::mock perl mock_non_existing_fn
  bashunit::mock clock::shell_time mock_non_existing_fn
  bashunit::mock dependencies::has_python mock_false
  bashunit::mock dependencies::has_node mock_false
  bashunit::mock date mock_non_existing_fn

  assert_empty "$(clock::total_runtime_in_milliseconds)"
}
