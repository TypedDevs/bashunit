#!/usr/bin/env bash

function test_default_os() {
  mock uname echo "bogus OS"

  check_os::init
  assert_equals "Unknown" "$_OS"
}

function test_detect_linux_os() {
  mock uname echo "Linux"
  mock grep mock_non_existing_fn

  check_os::init
  assert_equals "Linux" "$_OS"
}

function test_detect_alpine_linux_os() {
  mock uname echo "Linux"
  mock check_os::is_ubuntu mock_false
  mock check_os::is_alpine mock_true
  check_os::init

  assert_equals "Linux" "$_OS"
  assert_equals "Alpine" "$_DISTRO"
}

function test_detect_alpine_os_file() {
  mock uname echo "Linux"
  mock check_os::is_ubuntu mock_false
  mock check_os::is_alpine mock_true

  assert_successful_code "$(check_os::is_alpine)"
}

function test_detect_osx_os() {
  mock uname echo "Darwin"

  check_os::init
  assert_equals "OSX" "$_OS"
}

# @data_provider window_linux_variations
function test_detect_windows_os() {
  local windows_linux="$1"
  mock uname echo "$windows_linux"

  check_os::init
  assert_equals "Windows" "$_OS"
}

function window_linux_variations() {
  data_set "MINGW"
  data_set "junkMINGWjunk"
  data_set "MSYS_NT-10.0"
  data_set "junkMSYSjunk"
  data_set "CYGWIN_NT-10.0"
  data_set "junkCYGWINjunk"
}

function test_alpine_is_busybox() {

  mock uname echo "Linux"
  mock check_os::is_ubuntu mock_false
  mock check_os::is_alpine mock_true
  check_os::init
  assert_successful_code "$(check_os::is_alpine)"
  assert_successful_code "$(check_os::is_busybox)"
}

function test_not_alpine_is_not_busybox() {

  mock uname echo "Linux"
  mock check_os::is_ubuntu mock_true
  mock check_os::is_alpine mock_false
  check_os::init
  assert_general_error "$(check_os::is_alpine)"
  assert_general_error "$(check_os::is_busybox)"
}
