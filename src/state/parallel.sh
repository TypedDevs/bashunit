#!/usr/bin/env bash

# Aggregating per-test result files after a --parallel run.

##
# Folds every parallel worker's `.result` payload back into this shell's
# counters and assertion totals.
#
# Lives here rather than in parallel.sh because it decodes the very payload
# `bashunit::state::export_subshell_context` writes: keeping the encoder and the
# decoder in one module removes the parallel.sh <-> state.sh call cycle and stops
# the format from being described in two places.
#
# Arguments: $1 - the run's parallel temp directory
##
function bashunit::state::aggregate_parallel_results() {
  local temp_dir_parallel_test_suite=$1
  local IFS=$' \t\n'

  bashunit::internal_log "aggregate_parallel_results" "dir:$temp_dir_parallel_test_suite"

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
      result_line=$(<"$result_file")
      result_line="${result_line##*$'\n'}"

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

      # Read separately from the block above, and defaulted on its own, because a
      # payload without the field would leave the strip a no-op and hand the
      # guard below arbitrary text -- which would mark every test failed.
      local retries=0
      case "$result_line" in
      *"##TEST_RETRIES="*)
        retries="${result_line##*##TEST_RETRIES=}"
        retries="${retries%%##*}"
        case "$retries" in '' | *[!0-9]*) retries=0 ;; esac
        ;;
      esac

      # A truncated or non-payload .result line leaves every ##KEY= strip a
      # no-op, so these fields hold arbitrary text. `$(( ))` on such text is a
      # fatal arithmetic syntax error and `[ -gt ]` reports "integer expression
      # expected", so an unreadable result must degrade to zeros rather than
      # abort the aggregation. One `case` over the concatenation, no fork.
      case "$failed$passed$skipped$incomplete$snapshot$exit_code" in
      *[!0-9]*)
        failed=0 passed=0 skipped=0 incomplete=0 snapshot=0
        # An unparseable result is a failed test, not a silently passing one.
        exit_code=1
        bashunit::internal_log "aggregate_parallel_results" "unparseable result file:$result_file"
        ;;
      esac

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

      # Check for risky test (zero assertions, no error)
      local total_for_test=$((failed + passed + skipped + incomplete + snapshot))
      if [ "$total_for_test" -eq 0 ] && [ "${exit_code:-0}" -eq 0 ]; then
        if bashunit::env::is_fail_on_risky_enabled; then
          bashunit::state::add_tests_failed
        else
          bashunit::state::add_tests_risky
        fi
        continue
      fi

      if [ "$retries" -gt 0 ]; then
        bashunit::state::add_tests_flaky
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

