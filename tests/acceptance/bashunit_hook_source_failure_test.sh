#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_tear_down_sources_nonexistent_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_sources_nonexistent_file.sh

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_set_up_before_script_sources_nonexistent_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_setup_before_script_sources_nonexistent_file.sh

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_tear_down_after_script_sources_nonexistent_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_after_script_sources_nonexistent_file.sh

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

# A file that fails to source without writing anything to stderr used to report
# only "Failed to source 'x' (exit N)", which cannot distinguish a truncated
# file from one whose last command simply returned non-zero -- the difference
# that matters when it only happens on loaded CI (#1137).
function test_a_silent_source_failure_reports_the_file_size() {
  local fixture
  fixture="$(bashunit::temp_file silent_source).sh"
  printf 'function test_x() { assert_same 1 1; }\nfalse\n' >"$fixture"

  local actual
  set +e
  actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1)"
  set -e

  assert_contains "no stderr" "$(printf '%s' "$actual" | strip_ansi)"
  assert_contains "bytes" "$(printf '%s' "$actual" | strip_ansi)"
}

# The bashunit::temp_file a fixture creates at its top level before it fails to
# source. Echoed whether or not the run swept it, so the caller can assert on it.
# Arguments: $@ - the flags to run bashunit with
function _script_temp_file_of_failed_source() {
  local fixture leak_record
  fixture="$(bashunit::temp_file source_failure_sweep).sh"
  leak_record="$(bashunit::temp_file source_failure_sweep_record)"
  {
    printf 'printf "%%s\\n" "$(bashunit::temp_file leaky)" >"$LEAK_RECORD"\n'
    printf 'function test_x() { assert_same 1 1; }\n'
    printf 'false\n'
  } >"$fixture"

  set +e
  LEAK_RECORD="$leak_record" ./bashunit "$@" --env "$TEST_ENV_FILE" "$fixture" >/dev/null 2>&1
  set -e

  cat "$leak_record"
}

# Everything above the failure has already run, so the file may own script temp
# files. This path skipped the sweep and they survived the run (#1325).
function test_a_source_failure_sweeps_the_files_script_temp_files() {
  local leaked
  leaked="$(_script_temp_file_of_failed_source --no-parallel)"

  # Without this the next assertion passes vacuously: an empty path is no file.
  assert_not_empty "$leaked"
  assert_file_not_exists "$leaked"
}

# --list dispatches no worker, so the end-of-run loop that sweeps every id under
# --parallel is skipped. The sweep here is therefore unconditional, not behind
# the is_enabled guard the other paths out of the loop use (#1325).
function test_a_source_failure_sweeps_its_temp_files_under_parallel_list() {
  local leaked
  leaked="$(_script_temp_file_of_failed_source --parallel --list)"

  assert_not_empty "$leaked"
  assert_file_not_exists "$leaked"
}
