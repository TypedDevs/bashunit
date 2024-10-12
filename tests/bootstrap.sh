#!/bin/bash
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
  mock check_os::is_linux mock_true

  mock check_os::is_ubuntu mock_false
  mock check_os::is_alpine mock_false
  mock check_os::is_busybox mock_false
  mock check_os::is_macos mock_false
  mock check_os::is_windows mock_false
}


function mock_ubuntu_os() {
  mock check_os::is_linux mock_true
  mock check_os::is_ubuntu mock_true

  mock check_os::is_alpine mock_false
  mock check_os::is_busybox mock_false
  mock check_os::is_macos mock_false
  mock check_os::is_windows mock_false
}

function mock_alpine_os() {
  mock check_os::is_linux mock_true
  mock check_os::is_alpine mock_true
  mock check_os::is_busybox mock_true

  mock check_os::is_ubuntu mock_false
  mock check_os::is_macos mock_false
  mock check_os::is_windows mock_false
}

function mock_macos() {
  mock check_os::is_macos mock_true

  mock check_os::is_linux mock_false
  mock check_os::is_alpine mock_false
  mock check_os::is_ubuntu mock_false
  mock check_os::is_busybox mock_false
  mock check_os::is_windows mock_false
}

function mock_windows_os() {
  mock check_os::is_windows mock_true

  mock check_os::is_linux mock_false
  mock check_os::is_alpine mock_false
  mock check_os::is_ubuntu mock_false
  mock check_os::is_busybox mock_false
  mock check_os::is_macos mock_false
}
