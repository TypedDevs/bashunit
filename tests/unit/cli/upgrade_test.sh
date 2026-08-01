#!/usr/bin/env bash

# shellcheck disable=SC2329 # Test functions are invoked indirectly by bashunit

function set_up() {
  WORK_DIR="$(mktemp -d)"
  export BASHUNIT_INSTALL_DIR="$WORK_DIR"
}

function tear_down() {
  unset BASHUNIT_INSTALL_DIR
  rm -rf "$WORK_DIR"
}

function fake_get_latest_tag() {
  echo "9.9.9"
}

function fake_get_empty_tag() {
  echo ""
}

function fake_download_fail() {
  echo "curl: (6) Could not resolve host: github.com" >&2
  return 1
}

function fake_download_success() {
  local _url="$1"
  local output="$2"
  printf '#!/usr/bin/env bash\necho fake\n' >"$output"
}

function fake_download_empty() {
  local _url="$1"
  local output="$2"
  : >"$output"
}

function fake_get_current_tag() {
  echo "$BASHUNIT_VERSION"
}

function test_upgrade_aborts_when_download_fails() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_fail

  local output
  local exit_code=0
  output="$(bashunit::upgrade::upgrade 2>&1)" || exit_code=$?

  assert_contains "Failed to download bashunit 9.9.9 from" "$output"
  assert_contains "https://github.com/TypedDevs/bashunit/releases/download/9.9.9/bashunit" "$output"
  assert_not_contains "upgraded successfully" "$output"
  assert_equals "1" "$exit_code"
  assert_file_not_exists "$WORK_DIR/bashunit"
}

function test_upgrade_surfaces_underlying_download_error_message() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_fail

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)" || true

  assert_contains "Reason:" "$output"
  assert_contains "Could not resolve host" "$output"
}

function test_upgrade_aborts_when_downloaded_file_is_empty() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_empty

  local output
  local exit_code=0
  output="$(bashunit::upgrade::upgrade 2>&1)" || exit_code=$?

  assert_contains "empty file" "$output"
  assert_not_contains "upgraded successfully" "$output"
  assert_equals "1" "$exit_code"
  assert_file_not_exists "$WORK_DIR/bashunit"
}

function test_upgrade_aborts_when_latest_tag_cannot_be_resolved() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_empty_tag

  local output
  local exit_code=0
  output="$(bashunit::upgrade::upgrade 2>&1)" || exit_code=$?

  assert_contains "Failed to resolve latest bashunit version" "$output"
  assert_equals "1" "$exit_code"
}

function test_upgrade_reports_success_when_download_succeeds() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_latest_tag
  bashunit::mock bashunit::io::download_to fake_download_success

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)"

  assert_contains "Upgrading bashunit to latest version" "$output"
  assert_contains "upgraded successfully to latest version 9.9.9" "$output"
  assert_not_contains "Failed to download" "$output"
  assert_file_exists "$WORK_DIR/bashunit"
  assert_successful_code "$([ -x "$WORK_DIR/bashunit" ] && echo 0 || echo 1)"
}

function test_upgrade_skips_when_already_on_latest() {
  bashunit::mock bashunit::helper::get_latest_tag fake_get_current_tag

  local output
  output="$(bashunit::upgrade::upgrade 2>&1)"

  assert_contains "You are already on latest version" "$output"
  assert_not_contains "Failed to download" "$output"
  assert_not_contains "upgraded successfully" "$output"
}
