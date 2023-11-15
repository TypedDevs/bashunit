#!/bin/bash

function set_up_before_script() {
  ./build.sh >/dev/null
  assert_file_exists "./bin/bashunit"
}

function tear_down_after_script() {
    rm -f ./bin/bashunit
}

function test_bashunit_upgrade_on_latest() {
    local output

    output="$(./bin/bashunit --upgrade)"

    assert_equals\
    "$(printf "> You are already on latest release.")" "$output"
}

function test_fake_bashunit_upgrade() {
    sed -i -e 's/declare -r BASHUNIT_VERSION="[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}"/declare -r \
    BASHUNIT_VERSION="0.1.0"/' ./bin/bashunit

    output="$(./bin/bashunit --upgrade)"

    assert_contains "$(printf "> Upgrading bashunit to latest release.")" "$output"
    assert_contains "$(printf "> bashunit upgraded successfully to latest version ")" "$output"
}
