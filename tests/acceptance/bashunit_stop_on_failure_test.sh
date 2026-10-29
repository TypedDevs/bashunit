#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_STOP_ON_FAILURE="tests/acceptance/fixtures/.env.stop_on_failure"
}

function test_bashunit_when_stop_on_failure_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
}

function test_bashunit_when_stop_on_failure_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
}

function test_different_snapshots_matches() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  assert_match_named_snapshot "option" \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
  assert_match_named_snapshot "env" \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
}

function test_bashunit_when_stop_on_failure_env_simple_output() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file" --simple)"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file" --simple)"
}

function test_bashunit_stop_on_failure_with_runtime_error() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_stop_on_failure_runtime_error.sh
  local output=""
  local exit_code=0

  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")" || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "A runtime error" "$output"
  assert_not_contains "B not executed" "$output"
}

function provide_stop_report_modes() {
  bashunit::data_set --no-parallel
  bashunit::data_set --parallel
}

# @data_provider provide_stop_report_modes
function test_stopped_runs_write_all_requested_reports_and_the_rerun_cache() {
  local mode="$1" dir status=0 output report
  local fixture=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh
  dir="$(bashunit::temp_dir stopped_reports)"
  output=$(BASHUNIT_RERUN_CACHE_DIR="$dir/cache" ./bashunit --env "$TEST_ENV_FILE" \
    --jobs 1 "$mode" --stop-on-failure --log-junit "$dir/junit.xml" --report-json "$dir/result.json" \
    --report-html "$dir/result.html" --report-tap "$dir/result.tap" --report-md "$dir/result.md" \
    --log-gha "$dir/annotations.log" "$fixture" 2>&1) || status=$?

  assert_same 1 "$status"
  for report in junit.xml result.json result.html result.tap result.md annotations.log; do
    assert_file_exists "$dir/$report"
    if [ ! -f "$dir/$report" ]; then
      return
    fi
    assert_contains 'B error' "$(cat "$dir/$report")"
    if [ "$mode" = --no-parallel ]; then
      assert_not_contains 'C not executed' "$(cat "$dir/$report")"
    fi
  done
  assert_contains ':test_b_error' "$(cat "$dir/cache/last-failed")"

  status=0
  output=$(BASHUNIT_RERUN_CACHE_DIR="$dir/cache" ./bashunit --env "$TEST_ENV_FILE" \
    "$mode" --rerun-failed "$fixture" 2>&1) || status=$?
  assert_same 1 "$status"
  assert_contains 'B error' "$output"
  assert_not_contains 'A success' "$output"
  assert_not_contains 'C not executed' "$output"
}

function test_stop_on_failure_skips_remaining_provider_rows_and_later_files() {
  local dir output status=0
  dir="$(bashunit::temp_dir stopped_provider)"
  printf 'function %s() { printf "1\\n2\\n"; }\n' provide_stopped_rows >"$dir/a_test.sh"
  printf '# @data_provider provide_stopped_rows\nfunction %s() { assert_same 0 "$1"; }\n' \
    test_stopping_provider >>"$dir/a_test.sh"
  printf 'function %s() { assert_true true; }\n' test_later_file_not_run >"$dir/b_test.sh"
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-color --stop-on-failure "$dir" 2>&1) || status=$?

  assert_same 1 "$status"
  assert_contains '1 failed, 1 total' "$output"
  assert_not_contains 'Later file not run' "$output"
}

function test_bashunit_stop_on_failure_runs_tear_down_after_script() {
  local dir fixture marker
  dir="$(bashunit::temp_dir stop_on_failure_teardown)"
  fixture="$dir/halted_test.sh"
  marker="$dir/resource"
  {
    printf 'RESOURCE=""\n'
    printf 'function set_up_before_script() {\n'
    printf '  RESOURCE="$HALT_MARKER"\n'
    printf '  : >"$RESOURCE"\n'
    printf '}\n'
    printf 'function tear_down_after_script() {\n'
    printf '  rm -f "$RESOURCE"\n'
    printf '}\n'
    printf 'function test_a_halts_the_run() { assert_same 1 2; }\n'
    printf 'function test_b_not_executed() { assert_same 1 1; }\n'
  } >"$fixture"

  local output="" exit_code=0
  output="$(HALT_MARKER="$marker" ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --stop-on-failure "$fixture")" || exit_code=$?

  assert_same 1 "$exit_code"
  assert_not_contains "B not executed" "$output"
  assert_file_not_exists "$marker"
}

# A hook that fails while the run is halting still has to report itself, and must
# not turn the halt into a different exit code (#1321).
function test_bashunit_stop_on_failure_reports_a_failing_tear_down_after_script() {
  local dir fixture
  dir="$(bashunit::temp_dir stop_on_failure_teardown_error)"
  fixture="$dir/halted_bad_teardown_test.sh"
  {
    printf 'function set_up_before_script() { :; }\n'
    printf 'function tear_down_after_script() { missing_cleanup_command; }\n'
    printf 'function test_a_halts_the_run() { assert_same 1 2; }\n'
  } >"$fixture"

  local output="" exit_code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --stop-on-failure "$fixture" 2>&1)" || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "Tear down after script" "$(printf "%s" "$output" | strip_ansi)"
}
