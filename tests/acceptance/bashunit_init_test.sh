#!/usr/bin/env bash
# shellcheck disable=SC2317

set -euo pipefail

TMP_DIR="tmp/init"
function set_up() {
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
}

function tear_down() {
  rm -rf "$TMP_DIR"
}

function test_bashunit_init_creates_structure() {
  # switch into a clean temporary directory
  pushd "$TMP_DIR" >/dev/null
  # generate test scaffolding
  ../../bashunit init > /tmp/init.log
  # perform the assertions
  assert_file_exists "tests/example_test.sh"
  assert_file_exists "tests/bootstrap.sh"
  # return to the original working directory
  popd >/dev/null
}

function test_bashunit_init_custom_directory() {
  pushd "$TMP_DIR" >/dev/null
  ../../bashunit init custom > /tmp/init.log
  assert_file_exists "custom/example_test.sh"
  assert_file_exists "custom/bootstrap.sh"
  popd >/dev/null
}

function test_bashunit_init_updates_env() {
  bashunit::skip "flaky" && return

  pushd "$TMP_DIR" >/dev/null
  echo "BASHUNIT_BOOTSTRAP=old/bootstrap.sh" > .env
  ../../bashunit init custom > /tmp/init.log
  assert_file_exists "custom/example_test.sh"
  assert_file_exists "custom/bootstrap.sh"
  assert_file_contains .env "#BASHUNIT_BOOTSTRAP=old/bootstrap.sh"
  assert_file_contains .env "BASHUNIT_BOOTSTRAP=custom/bootstrap.sh"
  popd >/dev/null
}
