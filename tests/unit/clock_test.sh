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

function test_now_with_perl() {
  mock clock::shell_time mock_non_existing_fn
  mock perl echo "1720705883457"
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_unknown() {
  mock_unknown_linux_os
  mock clock::shell_time mock_non_existing_fn
  mock perl mock_non_existing_fn
  mock date echo "1720705883457"
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_alpine() {
  mock_alpine_os
  mock clock::shell_time mock_non_existing_fn
  mock perl echo "1720705883457"
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_windows_without_with_powershell() {
  mock_windows_os
  mock dependencies::has_perl mock_false
  mock dependencies::has_powershell mock_true
  mock powershell echo "1727768183281580800"
  mock clock::shell_time mock_non_existing_fn
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "1727768183281580800" "$(clock::now)"
}

function test_now_on_windows_without_without_powershell() {
  mock_windows_os
  mock dependencies::has_perl mock_false
  mock dependencies::has_powershell mock_false
  mock date echo "1727768951"
  mock clock::shell_time mock_non_existing_fn
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "1727768951" "$(clock::now)"
}

function test_now_on_osx_without_perl() {
  if ! check_os::is_macos; then
    skip
    return
  fi

  mock_macos
  mock dependencies::has_perl mock_false
  mock clock::shell_time echo "1727708708.326957"
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "1727708708326957000" "$(clock::now)"
}

function test_runtime_in_milliseconds_when_not_empty_time() {
  mock perl echo "1720705883457"
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_not_empty "$(clock::total_runtime_in_milliseconds)"
}

function test_now_prefers_perl_over_shell_time() {
  mock clock::shell_time echo "1234.0"
  mock perl echo "999999999999"
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_same "999999999999" "$(clock::now)"
}

function test_runtime_in_milliseconds_when_empty_time() {
  mock_macos
  mock perl mock_non_existing_fn
  mock clock::shell_time mock_non_existing_fn
  mock dependencies::has_python mock_false
  mock dependencies::has_node mock_false

  assert_empty "$(clock::total_runtime_in_milliseconds)"
}
