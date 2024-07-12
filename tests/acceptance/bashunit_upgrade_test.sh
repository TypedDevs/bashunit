#!/bin/bash
set -euo pipefail

function set_up() {
  ./build.sh >/dev/null
  LATEST_VERSION="$(helpers::get_latest_tag)"
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function tear_down() {
  rm -f ./bin/bashunit
}

function test_do_not_upgrade_when_latest() {
  local output
  output="$(./bin/bashunit --upgrade)"

  assert_equals "> You are already on latest version" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$(./bin/bashunit --version --env "$TEST_ENV_FILE")"
}

function test_upgrade_when_a_new_version_found() {
  sed -i -e \
    's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r BASHUNIT_VERSION="0.1.0"/' \
    ./bin/bashunit

  if [[ $_OS == "OSX" ]]; then
    rm -f ./bin/bashunit-e
  fi

  local output
  output="$(./bin/bashunit --upgrade)"

  assert_contains "> Upgrading bashunit to latest version" "$output"
  assert_contains "> bashunit upgraded successfully to latest version $LATEST_VERSION" "$output"
  assert_string_ends_with "$LATEST_VERSION" "$(./bin/bashunit --version --env "$TEST_ENV_FILE")"
}

function test_do_not_update_on_consecutive_calls() {
  todo "enable this test when --upgrade is released"
#  sed -i -e \
#    's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r BASHUNIT_VERSION="0.1.0"/' \
#    ./bin/bashunit
#
#  if [[ $_OS == "OSX" ]]; then
#    rm ./bin/bashunit-e
#  fi
#
#  ./bin/bashunit --upgrade
#  ./bin/bashunit --version
#
#  local output
#  output="$(./bin/bashunit --upgrade)"
#
#  assert_equals "> You are already on latest version" "$output"
#  assert_string_ends_with "$LATEST_VERSION" "$(./bin/bashunit --version --env "$TEST_ENV_FILE")"
}
