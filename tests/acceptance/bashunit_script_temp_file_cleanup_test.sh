#!/usr/bin/env bash

# @data_provider execution_modes
function test_script_temp_files_are_cleaned_up_after_test_run() {
  local mode="$1"
  local fixture_file="tests/acceptance/fixtures/script_with_setup_temp_file.sh"
  local temp_base_dir="${TMPDIR:-/tmp}/bashunit/tmp"
  local parallel_temp_base_dir="${TMPDIR:-/tmp}/bashunit/parallel/${_OS:-Unknown}"
  local output

  if [[ "$mode" == "parallel" ]]; then
    output=$(./bashunit --parallel "$fixture_file" 2>&1)
  else
    output=$(./bashunit "$fixture_file" 2>&1)
  fi

  # Check that the test run was successful
  assert_contains "All tests passed" "$output"

  # Check that no script-setup temp files remain in the temp directory
  local remaining_files
  if [[ -d "$temp_base_dir" ]]; then
    remaining_files=$(find "$temp_base_dir" -name "*script-setup*" 2>/dev/null || true)

    assert_empty "$remaining_files"

    # Manually clean up remaining files
    if [[ -n "$remaining_files" ]]; then
      echo "$remaining_files" | xargs rm -rf 2>/dev/null || true
    fi
  fi

  # Check that no parallel temp files remain in the temp directory

  if [[ -d "$parallel_temp_base_dir" ]]; then
    remaining_files=$(find "$parallel_temp_base_dir" -name "script_with_setup_temp_file" 2>/dev/null || true)

    assert_empty "$remaining_files"

    # Manually clean up remaining files
    if [[ -n "$remaining_files" ]]; then
      dirname "$remaining_files" | xargs rm -rf 2>/dev/null || true
    fi
  fi
}

function execution_modes() {
  echo "sequential"
  echo "parallel"
}
