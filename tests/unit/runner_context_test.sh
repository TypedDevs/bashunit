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
