#!/usr/bin/env bash

# Fixture for bashunit::skip_on. The OS names are resolved at run time so the
# same file proves both branches on every platform CI runs.

function current_os() {
  if bashunit::check_os::is_windows; then
    echo "windows"
  elif bashunit::check_os::is_macos; then
    echo "macos"
  else
    echo "linux"
  fi
}

function another_os() {
  if bashunit::check_os::is_windows; then
    echo "linux"
  else
    echo "windows"
  fi
}

function test_skip_on_the_current_os() {
  bashunit::skip_on "$(current_os)" "not for this os"
  assert_same "unreachable" "reached"
}

function test_skip_on_another_os_runs_the_body() {
  bashunit::skip_on "$(another_os)" "never used"
  assert_same "ok" "ok"
}

function test_skip_on_an_unknown_os() {
  bashunit::skip_on "plan9" "typo in the os name"
  assert_same "ok" "ok"
}
