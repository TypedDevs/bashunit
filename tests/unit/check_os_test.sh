#!/usr/bin/env bash

function test_default_os() {
  bashunit::mock uname echo "bogus OS"

  bashunit::check_os::init
  assert_equals "Unknown" "$_BASHUNIT_OS"
}

function test_detect_linux_os() {
  bashunit::mock uname echo "Linux"
  bashunit::mock grep mock_non_existing_fn

  bashunit::check_os::init
  assert_equals "Linux" "$_BASHUNIT_OS"
}

function test_detect_alpine_linux_os() {
  bashunit::mock uname echo "Linux"
  bashunit::mock bashunit::check_os::is_ubuntu mock_false
  bashunit::mock bashunit::check_os::is_alpine mock_true
  bashunit::check_os::init

  assert_equals "Linux" "$_BASHUNIT_OS"
  assert_equals "Alpine" "$_BASHUNIT_DISTRO"
}

function test_detect_alpine_os_file() {
  bashunit::mock uname echo "Linux"
  bashunit::mock bashunit::check_os::is_ubuntu mock_false
  bashunit::mock bashunit::check_os::is_alpine mock_true

  assert_successful_code "$(bashunit::check_os::is_alpine)"
}

function test_detect_osx_os() {
  bashunit::mock uname echo "Darwin"

  bashunit::check_os::init
  assert_equals "OSX" "$_BASHUNIT_OS"
}

# @data_provider window_linux_variations
function test_detect_windows_os() {
  local windows_linux="$1"
  bashunit::mock uname echo "$windows_linux"

  bashunit::check_os::init
  assert_equals "Windows" "$_BASHUNIT_OS"
}

function window_linux_variations() {
  bashunit::data_set "MINGW"
  bashunit::data_set "junkMINGWjunk"
  bashunit::data_set "MSYS_NT-10.0"
  bashunit::data_set "junkMSYSjunk"
  bashunit::data_set "CYGWIN_NT-10.0"
  bashunit::data_set "junkCYGWINjunk"
}

function test_alpine_is_busybox() {

  bashunit::mock uname echo "Linux"
  bashunit::mock bashunit::check_os::is_ubuntu mock_false
  bashunit::mock bashunit::check_os::is_alpine mock_true
  bashunit::check_os::init
  assert_successful_code "$(bashunit::check_os::is_alpine)"
  assert_successful_code "$(bashunit::check_os::is_busybox)"
}

function test_not_alpine_is_not_busybox() {

  bashunit::mock uname echo "Linux"
  bashunit::mock bashunit::check_os::is_ubuntu mock_true
  bashunit::mock bashunit::check_os::is_alpine mock_false
  bashunit::check_os::init
  assert_general_error "$(bashunit::check_os::is_alpine)"
  assert_general_error "$(bashunit::check_os::is_busybox)"
}
