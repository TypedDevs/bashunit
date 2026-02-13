#!/usr/bin/env bash

# shellcheck disable=SC2034

function set_up_before_script() {
  _TEST_TEMP_DIR=""
  _ORIGINAL_TEMP_DIR_PARALLEL=""
  _ORIGINAL_TEMP_FILE_STOP=""
}

function set_up() {
  original_parallel_run=$BASHUNIT_PARALLEL_RUN
  export BASHUNIT_PARALLEL_RUN=true

  # Create isolated temp directory for tests
  _TEST_TEMP_DIR=$(mktemp -d)

  # Save and override global temp paths
  _ORIGINAL_TEMP_DIR_PARALLEL="${TEMP_DIR_PARALLEL_TEST_SUITE:-}"
  _ORIGINAL_TEMP_FILE_STOP="${TEMP_FILE_PARALLEL_STOP_ON_FAILURE:-}"

  export TEMP_DIR_PARALLEL_TEST_SUITE="$_TEST_TEMP_DIR/parallel_suite"
  export TEMP_FILE_PARALLEL_STOP_ON_FAILURE="$_TEST_TEMP_DIR/stop_on_failure"
}

function tear_down() {
  export BASHUNIT_PARALLEL_RUN=$original_parallel_run

  # Clean up test temp directory
  [[ -d "$_TEST_TEMP_DIR" ]] && rm -rf "$_TEST_TEMP_DIR"

  # Restore original paths
  export TEMP_DIR_PARALLEL_TEST_SUITE="$_ORIGINAL_TEMP_DIR_PARALLEL"
  export TEMP_FILE_PARALLEL_STOP_ON_FAILURE="$_ORIGINAL_TEMP_FILE_STOP"
}

# === is_enabled tests ===

function test_parallel_enabled_on_windows() {
  bashunit::mock bashunit::check_os::is_windows mock_true
  bashunit::mock bashunit::check_os::is_macos mock_false
  bashunit::mock bashunit::check_os::is_ubuntu mock_false

  assert_successful_code "$(bashunit::parallel::is_enabled)"
}

function test_parallel_enabled_on_macos() {
  bashunit::mock bashunit::check_os::is_windows mock_false
  bashunit::mock bashunit::check_os::is_macos mock_true
  bashunit::mock bashunit::check_os::is_ubuntu mock_false

  assert_successful_code "$(bashunit::parallel::is_enabled)"
}

function test_parallel_enabled_on_ubuntu() {
  bashunit::mock bashunit::check_os::is_windows mock_false
  bashunit::mock bashunit::check_os::is_macos mock_false
  bashunit::mock bashunit::check_os::is_ubuntu mock_true

  assert_successful_code "$(bashunit::parallel::is_enabled)"
}

function test_parallel_disabled_when_env_false() {
  export BASHUNIT_PARALLEL_RUN=false

  bashunit::mock bashunit::check_os::is_macos mock_true

  assert_general_error "$(bashunit::parallel::is_enabled)"
}

function test_parallel_disabled_on_unsupported_os() {
  bashunit::mock bashunit::check_os::is_windows mock_false
  bashunit::mock bashunit::check_os::is_macos mock_false
  bashunit::mock bashunit::check_os::is_ubuntu mock_false

  assert_general_error "$(bashunit::parallel::is_enabled)"
}

# === init/cleanup tests ===

function test_init_creates_temp_directory() {
  bashunit::parallel::init

  assert_directory_exists "$TEMP_DIR_PARALLEL_TEST_SUITE"
}

function test_cleanup_removes_temp_directory() {
  mkdir -p "$TEMP_DIR_PARALLEL_TEST_SUITE"

  bashunit::parallel::cleanup

  assert_directory_not_exists "$TEMP_DIR_PARALLEL_TEST_SUITE"
}

# === stop_on_failure tests ===

function test_mark_stop_on_failure_creates_file() {
  bashunit::parallel::mark_stop_on_failure

  assert_file_exists "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE"
}

function test_must_stop_on_failure_returns_true_when_file_exists() {
  touch "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE"

  assert_successful_code "$(bashunit::parallel::must_stop_on_failure)"
}

function test_must_stop_on_failure_returns_false_when_no_file() {
  rm -f "$TEMP_FILE_PARALLEL_STOP_ON_FAILURE"

  assert_general_error "$(bashunit::parallel::must_stop_on_failure)"
}

# === aggregate_test_results tests ===

function _create_result_file() {
  local dir="$1"
  local filename="$2"
  local content="$3"

  mkdir -p "$dir"
  echo "$content" >"$dir/$filename"
}

function test_aggregate_handles_no_result_files() {
  mkdir -p "$TEMP_DIR_PARALLEL_TEST_SUITE/script1"

  local output
  output=$(bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE")

  assert_contains "No tests found" "$output"
}

function test_aggregate_sets_passed_assertion_count() {
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test1.result" \
    "##ASSERTIONS_PASSED=5##ASSERTIONS_FAILED=0##TEST_EXIT_CODE=0##"

  # Run in subshell to isolate state changes
  local passed
  passed=$(
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE" >/dev/null
    echo "$_BASHUNIT_ASSERTIONS_PASSED"
  )

  assert_same "5" "$passed"
}

function test_aggregate_sets_failed_assertion_count() {
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test1.result" \
    "##ASSERTIONS_PASSED=3##ASSERTIONS_FAILED=2##TEST_EXIT_CODE=0##"

  local failed
  failed=$(
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE" >/dev/null
    echo "$_BASHUNIT_ASSERTIONS_FAILED"
  )

  assert_same "2" "$failed"
}

function test_aggregate_sets_skipped_assertion_count() {
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test1.result" \
    "##ASSERTIONS_PASSED=0##ASSERTIONS_FAILED=0##ASSERTIONS_SKIPPED=3##TEST_EXIT_CODE=0##"

  local skipped
  skipped=$(
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE" >/dev/null
    echo "$_BASHUNIT_ASSERTIONS_SKIPPED"
  )

  assert_same "3" "$skipped"
}

function test_aggregate_sets_incomplete_assertion_count() {
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test1.result" \
    "##ASSERTIONS_PASSED=0##ASSERTIONS_FAILED=0##ASSERTIONS_INCOMPLETE=2##TEST_EXIT_CODE=0##"

  local incomplete
  incomplete=$(
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE" >/dev/null
    echo "$_BASHUNIT_ASSERTIONS_INCOMPLETE"
  )

  assert_same "2" "$incomplete"
}

function test_aggregate_sets_snapshot_assertion_count() {
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test1.result" \
    "##ASSERTIONS_PASSED=0##ASSERTIONS_FAILED=0##ASSERTIONS_SNAPSHOT=4##TEST_EXIT_CODE=0##"

  local snapshot
  snapshot=$(
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE" >/dev/null
    echo "$_BASHUNIT_ASSERTIONS_SNAPSHOT"
  )

  assert_same "4" "$snapshot"
}

function test_aggregate_sums_multiple_result_files() {
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test1.result" \
    "##ASSERTIONS_PASSED=5##ASSERTIONS_FAILED=1##TEST_EXIT_CODE=0##"
  _create_result_file "$TEMP_DIR_PARALLEL_TEST_SUITE/script1" "test2.result" \
    "##ASSERTIONS_PASSED=3##ASSERTIONS_FAILED=2##TEST_EXIT_CODE=0##"

  local passed failed
  read -r passed failed < <(
    bashunit::parallel::aggregate_test_results "$TEMP_DIR_PARALLEL_TEST_SUITE" >/dev/null
    echo "$_BASHUNIT_ASSERTIONS_PASSED $_BASHUNIT_ASSERTIONS_FAILED"
  )

  assert_same "8" "$passed"
  assert_same "3" "$failed"
}
