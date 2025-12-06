#!/usr/bin/env bash
set -euo pipefail

function mock_non_existing_fn() {
  return 127;
}

function mock_false() {
  return 1;
}

function mock_true() {
  return 0;
}

function mock_unknown_linux_os() {
  bashunit::mock check_os::is_linux mock_true

  bashunit::mock check_os::is_ubuntu mock_false
  bashunit::mock check_os::is_alpine mock_false
  bashunit::mock check_os::is_busybox mock_false
  bashunit::mock check_os::is_macos mock_false
  bashunit::mock check_os::is_windows mock_false
}


function mock_ubuntu_os() {
  bashunit::mock check_os::is_linux mock_true
  bashunit::mock check_os::is_ubuntu mock_true

  bashunit::mock check_os::is_alpine mock_false
  bashunit::mock check_os::is_busybox mock_false
  bashunit::mock check_os::is_macos mock_false
  bashunit::mock check_os::is_windows mock_false
}

function mock_alpine_os() {
  bashunit::mock check_os::is_linux mock_true
  bashunit::mock check_os::is_alpine mock_true
  bashunit::mock check_os::is_busybox mock_true

  bashunit::mock check_os::is_ubuntu mock_false
  bashunit::mock check_os::is_macos mock_false
  bashunit::mock check_os::is_windows mock_false
}

function mock_macos() {
  bashunit::mock check_os::is_macos mock_true

  bashunit::mock check_os::is_linux mock_false
  bashunit::mock check_os::is_alpine mock_false
  bashunit::mock check_os::is_ubuntu mock_false
  bashunit::mock check_os::is_busybox mock_false
  bashunit::mock check_os::is_windows mock_false
}

function mock_windows_os() {
  bashunit::mock check_os::is_windows mock_true

  bashunit::mock check_os::is_linux mock_false
  bashunit::mock check_os::is_alpine mock_false
  bashunit::mock check_os::is_ubuntu mock_false
  bashunit::mock check_os::is_busybox mock_false
  bashunit::mock check_os::is_macos mock_false
}
