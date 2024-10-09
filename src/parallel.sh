#!/bin/bash

function parallel::aggregate_test_results() {
  local temp_dir_parallel_test_suite=$1

  local total_failed=0
  local total_passed=0
  local total_skipped=0
  local total_incomplete=0
  local total_snapshot=0

  for script_dir in "$temp_dir_parallel_test_suite"/*; do
    for result_file in "$script_dir"/*.result; do
      while IFS= read -r line; do
        # Extract assertion counts from the result lines using sed
        failed=$(echo "$line" | sed -n 's/.*##ASSERTIONS_FAILED=\([0-9]*\).*/\1/p')
        passed=$(echo "$line" | sed -n 's/.*##ASSERTIONS_PASSED=\([0-9]*\).*/\1/p')
        skipped=$(echo "$line" | sed -n 's/.*##ASSERTIONS_SKIPPED=\([0-9]*\).*/\1/p')
        incomplete=$(echo "$line" | sed -n 's/.*##ASSERTIONS_INCOMPLETE=\([0-9]*\).*/\1/p')
        snapshot=$(echo "$line" | sed -n 's/.*##ASSERTIONS_SNAPSHOT=\([0-9]*\).*/\1/p')

        # Default to 0 if no match is found
        failed=${failed:-0}
        passed=${passed:-0}
        skipped=${skipped:-0}
        incomplete=${incomplete:-0}
        snapshot=${snapshot:-0}

        # Add to the total counts
        total_failed=$((total_failed + failed))
        total_passed=$((total_passed + passed))
        total_skipped=$((total_skipped + skipped))
        total_incomplete=$((total_incomplete + incomplete))
        total_snapshot=$((total_snapshot + snapshot))
      done < "$result_file"

      if [ "${failed:-0}" -gt 0 ]; then
        state::add_tests_failed
        continue
      fi

      if [ "${snapshot:-0}" -gt 0 ]; then
        state::add_tests_snapshot
        continue
      fi

      if [ "${incomplete:-0}" -gt 0 ]; then
        state::add_tests_incomplete
        continue
      fi

      if [ "${skipped:-0}" -gt 0 ]; then
        state::add_tests_skipped
        continue
      fi

      state::add_tests_passed
    done
  done

  export _ASSERTIONS_FAILED=$total_failed
  export _ASSERTIONS_PASSED=$total_passed
  export _ASSERTIONS_SKIPPED=$total_skipped
  export _ASSERTIONS_INCOMPLETE=$total_incomplete
  export _ASSERTIONS_SNAPSHOT=$total_snapshot
}
