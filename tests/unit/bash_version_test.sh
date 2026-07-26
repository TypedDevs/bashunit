#!/usr/bin/env bash

# The floor is 3.0. The gate compares the minor too, so it enforces whatever
# BASHUNIT_MIN_BASH_VERSION declares instead of accepting every 3.x.

function test_fail_with_bash_2() {
  local output
  local exit_code=0
  output=$(BASHUNIT_TEST_BASH_VERSION=2.05 ./bashunit --version 2>&1) || exit_code=$?
  assert_contains "Bashunit requires Bash >= 3.0. Current version: 2.05" "$output"
  assert_general_error "$output" "" "$exit_code"
}

function test_accepts_bash_3_0() {
  local exit_code=0
  BASHUNIT_TEST_BASH_VERSION=3.0 ./bashunit --version >/dev/null 2>&1 || exit_code=$?
  assert_successful_code "" "" "$exit_code"
}

function test_accepts_bash_3_2() {
  local exit_code=0
  BASHUNIT_TEST_BASH_VERSION=3.2 ./bashunit --version >/dev/null 2>&1 || exit_code=$?
  assert_successful_code "" "" "$exit_code"
}

function test_accepts_bash_4_and_newer() {
  local exit_code=0
  BASHUNIT_TEST_BASH_VERSION=5.2 ./bashunit --version >/dev/null 2>&1 || exit_code=$?
  assert_successful_code "" "" "$exit_code"
}

function test_accepts_a_suffixed_version_string() {
  local exit_code=0
  BASHUNIT_TEST_BASH_VERSION="5.2.37(1)-release" ./bashunit --version >/dev/null 2>&1 || exit_code=$?
  assert_successful_code "" "" "$exit_code"
}

# At a 3.0 floor the minor comparison never rejects anything a major-only check
# would accept, so nothing above can tell the two apart. Run the real gate with
# the floor raised to prove it reads BASHUNIT_MIN_BASH_VERSION.
#
# The probe has to sit next to the real one: the entrypoint resolves src/ from
# its own location. mktemp keeps it unique, since --parallel runs the tests in
# this file concurrently and they would otherwise share the path.
function test_the_gate_enforces_the_declared_minimum() {
  local probe
  probe=$(mktemp ./.bashunit-floor-probe.XXXXXX)
  sed 's/BASHUNIT_MIN_BASH_VERSION="3.0"/BASHUNIT_MIN_BASH_VERSION="3.2"/' ./bashunit >"$probe"
  chmod +x "$probe"

  local output
  local exit_code=0
  output=$(BASHUNIT_TEST_BASH_VERSION=3.1 "$probe" --version 2>&1) || exit_code=$?
  rm -f "$probe"

  assert_contains "Bashunit requires Bash >= 3.2. Current version: 3.1" "$output"
  assert_general_error "$output" "" "$exit_code"
}
