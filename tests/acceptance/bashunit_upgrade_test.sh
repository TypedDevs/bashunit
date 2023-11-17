#!/bin/bash

function set_up() {
  ./build.sh >/dev/null
  LATEST_VERSION="$(./bin/bashunit --version)"
}

function tear_down() {
  rm -f ./bin/bashunit
}

function test_do_not_upgrade_when_latest() {
  local output
  output="$(./bin/bashunit --upgrade)"

  assert_equals "> You are already on latest release" "$output"
  assert_equals "$LATEST_VERSION" "$(./bin/bashunit --version)"
}

function test_upgrade_when_a_new_version_found() {
  sed -i -e \
    's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r BASHUNIT_VERSION="0.1.0"/' \
    ./bin/bashunit

  if [[ $_OS == "OSX" ]]; then
    rm ./bin/bashunit-e
  fi

  local output
  output="$(./bin/bashunit --upgrade)"
  echo "$output"

  assert_contains "> Upgrading bashunit to latest release" "$output"
  assert_contains "> bashunit upgraded successfully to latest version" "$output"
  assert_equals "$LATEST_VERSION" "$(./bin/bashunit --version)"
}

function test_do_not_update_on_consecutive_calls() {
  skip "until we have --upgrade released"
  return

  sed -i -e \
    's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r BASHUNIT_VERSION="0.1.0"/' \
    ./bin/bashunit

  if [[ $_OS == "OSX" ]]; then
    rm ./bin/bashunit-e
  fi

  ./bin/bashunit --upgrade
  ./bin/bashunit --version

  local output
  output="$(./bin/bashunit --upgrade)"

  assert_equals "> You are already on latest release" "$output"
  assert_equals "$LATEST_VERSION" "$(./bin/bashunit --version)"
}
