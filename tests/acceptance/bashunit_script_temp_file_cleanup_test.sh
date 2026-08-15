#!/usr/bin/env bash
# bashunit: no-parallel-tests

# @data_provider execution_modes
function test_script_temp_files_are_cleaned_up_after_test_run() {
  local mode="$1"
  local fixture_file="tests/acceptance/fixtures/script_with_setup_temp_file.sh"
  local temp_base_dir="${TMPDIR:-/tmp}/bashunit/tmp"
  local parallel_temp_base_dir="${TMPDIR:-/tmp}/bashunit/parallel/${_BASHUNIT_OS:-Unknown}"
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
    remaining_files=$(find "$parallel_temp_base_dir" \
      -name "script_with_setup_temp_file" 2>/dev/null || true)

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

# Cleanup stats one marker instead of expanding a glob over BASHUNIT_TEMP_DIR.
# That directory is shared and survives between runs, so anything an
# interrupted run left there used to be re-examined by every test of every
# later run -- and could never match, since the id carries the run's own $$.
#
# Deterministic guard rather than a timing one: a file the test wrote itself,
# named with its own id, is reachable *only* by scanning the directory. It
# surviving proves no scan happened. A test that used the helper still has its
# file removed, which is the behaviour that must not regress.
function test_cleanup_does_not_read_the_shared_temp_directory() {
  local fixture="tests/acceptance/fixtures/temp_marker_cleanup.sh"
  local spy_planted spy_handed
  spy_planted="$(bashunit::temp_file)"
  spy_handed="$(bashunit::temp_file)"

  local output
  output=$(MARKER_SPY_PLANTED="$spy_planted" MARKER_SPY_HANDED="$spy_handed" \
    ./bashunit --no-parallel "$fixture" 2>&1)

  assert_contains "2 passed" "$output"

  local planted handed
  planted="$(cat "$spy_planted")"
  handed="$(cat "$spy_handed")"

  assert_file_exists "$planted"
  assert_file_not_exists "$handed"

  rm -f "$planted"
}
