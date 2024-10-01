#!/bin/bash

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
  mock perl echo "1720705883457"

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_unknown() {
  mock_unknown_linux_os
  mock perl mock_non_existing_fn
  mock date echo "1720705883457"

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_alpine() {
  mock_alpine_os
  mock perl echo "1720705883457"

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_windows_without_with_powershell() {
  mock_windows_os
  mock dependencies::has_perl mock_false
  mock dependencies::has_powershell mock_true
  mock powershell echo "1727768183281580800"

  assert_same "1727768183281580800" "$(clock::now)"
}

function test_now_on_windows_without_without_powershell() {
  mock_windows_os
  mock dependencies::has_perl mock_false
  mock dependencies::has_powershell mock_false
  mock date echo "1727768951"

  assert_same "1727768951" "$(clock::now)"
}

function test_now_on_osx_without_perl() {
  mock_macos
  mock dependencies::has_perl mock_false
  mock clock::shell_time echo "1727708708.326957"

  assert_same "1727708708326957000" "$(clock::now)"
}

function test_runtime_in_milliseconds_when_not_empty_time() {
  mock perl echo "1720705883457"

  assert_not_empty "$(clock::total_runtime_in_milliseconds)"
}

function test_runtime_in_milliseconds_when_empty_time() {
  mock_macos
  mock perl mock_non_existing_fn
  mock clock::shell_time mock_non_existing_fn

  assert_empty "$(clock::total_runtime_in_milliseconds)"
}
