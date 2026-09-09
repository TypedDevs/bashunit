#!/usr/bin/env bash

function test_sync_coverage_flag_sets_one_when_enabled() {
  local _orig="${BASHUNIT_COVERAGE-}"
  BASHUNIT_COVERAGE="true"
  bashunit::runner::sync_coverage_flag
  assert_same "1" "$_BASHUNIT_COVERAGE_ON"
  BASHUNIT_COVERAGE="$_orig"
  bashunit::runner::sync_coverage_flag
}

function test_sync_coverage_flag_sets_zero_when_disabled() {
  local _orig="${BASHUNIT_COVERAGE-}"
  BASHUNIT_COVERAGE="false"
  bashunit::runner::sync_coverage_flag
  assert_same "0" "$_BASHUNIT_COVERAGE_ON"
  BASHUNIT_COVERAGE="$_orig"
  bashunit::runner::sync_coverage_flag
}

function test_sync_coverage_flag_sets_zero_when_unset() {
  local _orig="${BASHUNIT_COVERAGE-}"
  unset BASHUNIT_COVERAGE
  bashunit::runner::sync_coverage_flag
  assert_same "0" "$_BASHUNIT_COVERAGE_ON"
  BASHUNIT_COVERAGE="$_orig"
  bashunit::runner::sync_coverage_flag
}

function test_supports_reliable_pipefail_matches_bash_version() {
  # Reliable on Bash >= 3.1; Bash 3.0 ships a broken pipefail.
  local expected_rc=0
  if [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -eq 0 ]; then
    expected_rc=1
  fi

  local actual_rc=0
  bashunit::runner::_supports_reliable_pipefail || actual_rc=$?
  assert_same "$expected_rc" "$actual_rc"
}

# --- restore_workdir ----------------------------------------------------------

function test_restore_workdir_returns_to_the_given_directory() {
  local target
  target="$(bashunit::temp_dir)"

  local landed
  landed=$(
    cd / || exit 1
    bashunit::runner::restore_workdir "$target"
    pwd -P
  )

  assert_same "$(cd "$target" && pwd -P)" "$landed"
}

function test_restore_workdir_aborts_loudly_when_the_directory_is_gone() {
  local gone
  gone="$(bashunit::temp_dir)/removed"

  local status=0
  local output
  # `$(...)` is already a subshell, so the function's `exit 1` ends the capture
  # rather than the test.
  output="$(bashunit::runner::restore_workdir "$gone" 2>&1)" || status=$?

  assert_same 1 "$status"
  assert_contains "cannot restore the working directory" "$output"
  assert_contains "$gone" "$output"
}

# --- test location ------------------------------------------------------------

# Resolving "<file>:<line>" reads the definition line with
# `$(shopt -s extdebug; declare -F …)`, a subshell that costs 1.08ms on macOS
# arm64 — ~2.7s over this suite. Only a failure message and a report row ever
# read it, so the identity carries the inputs and nothing resolves up front
# (#1346).
function test_export_test_identity_leaves_the_location_unresolved() {
  local orig_id=${BASHUNIT_CURRENT_TEST_ID:-}
  local orig_location=${_BASHUNIT_TEST_LOCATION:-}
  local orig_file=${_BASHUNIT_TEST_LOCATION_FILE:-}
  local orig_fn=${_BASHUNIT_TEST_LOCATION_FN:-}

  bashunit::runner::export_test_identity "some_test.sh" "test_not_defined_here"

  assert_empty "$_BASHUNIT_TEST_LOCATION"
  assert_same "some_test.sh" "$_BASHUNIT_TEST_LOCATION_FILE"
  assert_same "test_not_defined_here" "$_BASHUNIT_TEST_LOCATION_FN"

  export BASHUNIT_CURRENT_TEST_ID="$orig_id"
  export _BASHUNIT_TEST_LOCATION="$orig_location"
  export _BASHUNIT_TEST_LOCATION_FILE="$orig_file"
  export _BASHUNIT_TEST_LOCATION_FN="$orig_fn"
}

function test_ensure_test_location_resolves_on_demand() {
  local orig_location=${_BASHUNIT_TEST_LOCATION:-}
  local orig_file=${_BASHUNIT_TEST_LOCATION_FILE:-}
  local orig_fn=${_BASHUNIT_TEST_LOCATION_FN:-}
  _BASHUNIT_TEST_LOCATION=""
  _BASHUNIT_TEST_LOCATION_FILE="mine.sh"
  _BASHUNIT_TEST_LOCATION_FN="test_ensure_test_location_resolves_on_demand"

  bashunit::runner::ensure_test_location

  assert_matches "^mine\.sh:[0-9]+$" "$_BASHUNIT_TEST_LOCATION"

  export _BASHUNIT_TEST_LOCATION="$orig_location"
  export _BASHUNIT_TEST_LOCATION_FILE="$orig_file"
  export _BASHUNIT_TEST_LOCATION_FN="$orig_fn"
}

# Resolved once per test: the failure path renders the suffix up to three
# times, and each would otherwise pay the subshell again.
function test_ensure_test_location_keeps_an_already_resolved_location() {
  local orig_location=${_BASHUNIT_TEST_LOCATION:-}
  local orig_file=${_BASHUNIT_TEST_LOCATION_FILE:-}
  local orig_fn=${_BASHUNIT_TEST_LOCATION_FN:-}
  _BASHUNIT_TEST_LOCATION="already/resolved.sh:7"
  _BASHUNIT_TEST_LOCATION_FILE="mine.sh"
  _BASHUNIT_TEST_LOCATION_FN="test_ensure_test_location_keeps_an_already_resolved_location"

  bashunit::runner::ensure_test_location

  assert_same "already/resolved.sh:7" "$_BASHUNIT_TEST_LOCATION"

  export _BASHUNIT_TEST_LOCATION="$orig_location"
  export _BASHUNIT_TEST_LOCATION_FILE="$orig_file"
  export _BASHUNIT_TEST_LOCATION_FN="$orig_fn"
}

# Nothing to resolve from, so nothing is claimed: an empty location renders no
# "at …" suffix at all.
function test_ensure_test_location_stays_empty_without_a_function_name() {
  local orig_location=${_BASHUNIT_TEST_LOCATION:-}
  local orig_file=${_BASHUNIT_TEST_LOCATION_FILE:-}
  local orig_fn=${_BASHUNIT_TEST_LOCATION_FN:-}
  _BASHUNIT_TEST_LOCATION=""
  _BASHUNIT_TEST_LOCATION_FILE=""
  _BASHUNIT_TEST_LOCATION_FN=""

  bashunit::runner::ensure_test_location

  assert_empty "$_BASHUNIT_TEST_LOCATION"

  export _BASHUNIT_TEST_LOCATION="$orig_location"
  export _BASHUNIT_TEST_LOCATION_FILE="$orig_file"
  export _BASHUNIT_TEST_LOCATION_FN="$orig_fn"
}
