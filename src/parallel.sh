#!/usr/bin/env bash

function bashunit::parallel::aggregate_test_results() {
  local temp_dir_parallel_test_suite=$1
  local IFS=$' \t\n'

  bashunit::internal_log "aggregate_test_results" "dir:$temp_dir_parallel_test_suite"

  local total_failed=0
  local total_passed=0
  local total_skipped=0
  local total_incomplete=0
  local total_snapshot=0

  local script_dir=""
  for script_dir in "$temp_dir_parallel_test_suite"/*; do
    shopt -s nullglob
    # Bash 3.0 compatible: separate declaration and assignment for arrays
    local result_files
    result_files=("$script_dir"/*.result)
    shopt -u nullglob

    if [ ${#result_files[@]} -eq 0 ]; then
      printf "%sNo tests found%s" "$_BASHUNIT_COLOR_SKIPPED" "$_BASHUNIT_COLOR_DEFAULT"
      continue
    fi

    local result_file=""
    for result_file in "${result_files[@]+"${result_files[@]}"}"; do
      local result_line
      result_line=$(tail -n 1 <"$result_file")

      local failed="${result_line##*##ASSERTIONS_FAILED=}"
      failed="${failed%%##*}"
      failed=${failed:-0}

      local passed="${result_line##*##ASSERTIONS_PASSED=}"
      passed="${passed%%##*}"
      passed=${passed:-0}

      local skipped="${result_line##*##ASSERTIONS_SKIPPED=}"
      skipped="${skipped%%##*}"
      skipped=${skipped:-0}

      local incomplete="${result_line##*##ASSERTIONS_INCOMPLETE=}"
      incomplete="${incomplete%%##*}"
      incomplete=${incomplete:-0}

      local snapshot="${result_line##*##ASSERTIONS_SNAPSHOT=}"
      snapshot="${snapshot%%##*}"
      snapshot=${snapshot:-0}

      local exit_code="${result_line##*##TEST_EXIT_CODE=}"
      exit_code="${exit_code%%##*}"
      exit_code=${exit_code:-0}

      # Add to the total counts
      total_failed=$((total_failed + failed))
      total_passed=$((total_passed + passed))
      total_skipped=$((total_skipped + skipped))
      total_incomplete=$((total_incomplete + incomplete))
      total_snapshot=$((total_snapshot + snapshot))

      if [ "${failed:-0}" -gt 0 ]; then
        bashunit::state::add_tests_failed
        continue
      fi

      if [ "${exit_code:-0}" -ne 0 ]; then
        bashunit::state::add_tests_failed
        continue
      fi

      if [ "${snapshot:-0}" -gt 0 ]; then
        bashunit::state::add_tests_snapshot
        continue
      fi

      if [ "${incomplete:-0}" -gt 0 ]; then
        bashunit::state::add_tests_incomplete
        continue
      fi

      if [ "${skipped:-0}" -gt 0 ]; then
        bashunit::state::add_tests_skipped
        continue
      fi

      bashunit::state::add_tests_passed
    done
  done

  export _BASHUNIT_ASSERTIONS_FAILED=$total_failed
  export _BASHUNIT_ASSERTIONS_PASSED=$total_passed
  export _BASHUNIT_ASSERTIONS_SKIPPED=$total_skipped
  export _BASHUNIT_ASSERTIONS_INCOMPLETE=$total_incomplete
  export _BASHUNIT_ASSERTIONS_SNAPSHOT=$total_snapshot

  bashunit::internal_log "aggregate_totals" \
    "failed:$total_failed" \
    "passed:$total_passed" \
    "skipped:$total_skipped" \
    "incomplete:$total_incomplete" \
    "snapshot:$total_snapshot"
}

function bashunit::parallel::mark_stop_on_failure() {
  touch "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE"
}

function bashunit::parallel::must_stop_on_failure() {
  [[ -f "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE" ]]
}

function bashunit::parallel::cleanup() {
  # shellcheck disable=SC2153
  rm -rf "$TEMP_DIR_PARALLEL_TEST_SUITE"
}

function bashunit::parallel::init() {
  bashunit::parallel::cleanup
  mkdir -p "$TEMP_DIR_PARALLEL_TEST_SUITE"
}

function bashunit::parallel::is_enabled() {
  bashunit::internal_log "bashunit::parallel::is_enabled" \
    "requested:$BASHUNIT_PARALLEL_RUN" "os:${_BASHUNIT_OS:-Unknown}"

  if bashunit::env::is_parallel_run_enabled &&
    (bashunit::check_os::is_macos || bashunit::check_os::is_ubuntu || bashunit::check_os::is_windows); then
    return 0
  fi
  return 1
}
