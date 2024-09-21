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
  export _OS="Linux"
  export _DISTRO="Unknown"
  mock perl mock_non_existing_fn
  mock date echo "1720705883457"

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_linux_alpine() {
  export _OS="Linux"
  export _DISTRO="Alpine"
  mock perl mock_non_existing_fn
  mock awk echo "1720705883457"

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_windows_without_perl() {
  export _OS="Windows"
  mock perl mock_non_existing_fn
  mock date echo "1720705883457"

  assert_same "1720705883457" "$(clock::now)"
}

function test_now_on_osx_without_perl() {
  export _OS="OSX"
  mock perl mock_non_existing_fn

  assert_same "" "$(clock::now)"
}

function test_runtime_in_milliseconds_when_not_empty_time() {
  mock perl echo "1720705883457"

  assert_not_empty "$(clock::total_runtime_in_milliseconds)"
}

function test_runtime_in_milliseconds_when_empty_time() {
  export _OS="OSX"
  mock perl mock_non_existing_fn

  assert_empty "$(clock::total_runtime_in_milliseconds)"
}
