#!/bin/bash
set -euo pipefail

TMP_DIR="tmp"
TMP_BIN="$TMP_DIR/bashunit"

function set_up() {
  ./build.sh "$TMP_DIR" >/dev/null
  LATEST_VERSION="$(helpers::get_latest_tag)"
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function tear_down() {
  rm -rf "$TMP_DIR"
}

function test_do_not_upgrade_when_latest() {
  local output
  output="$($TMP_BIN --upgrade)"

  assert_same "> You are already on latest version" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$($TMP_BIN --version --env "$TEST_ENV_FILE")"
}

function test_upgrade_when_a_new_version_found() {
  sed -i -e \
    's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r BASHUNIT_VERSION="0.1.0"/' \
    "$TMP_BIN"

  if [[ $_OS == "OSX" ]]; then
    rm -f "${TMP_BIN}-e"
  fi

  local output
  output="$($TMP_BIN --upgrade)"

  assert_contains "> Upgrading bashunit to latest version" "$output"
  assert_contains "> bashunit upgraded successfully to latest version $LATEST_VERSION" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$($TMP_BIN --version --env "$TEST_ENV_FILE")"
}

function test_do_not_update_on_consecutive_calls() {
  sed -i -e \
    's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r BASHUNIT_VERSION="0.1.0"/' \
    $TMP_BIN

  if [[ $_OS == "OSX" ]]; then
    rm $TMP_BIN-e
  fi

  $TMP_BIN --upgrade
  $TMP_BIN --version

  local output
  output="$($TMP_BIN --upgrade)"

  assert_same "> You are already on latest version" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$($TMP_BIN --version --env "$TEST_ENV_FILE")"
}
