#!/usr/bin/env bash

function bashunit::runner::parse_result() {
  local fn_name=$1
  shift
  local execution_result=$1
  shift
  local IFS=$' \t\n'
  local -a args
  args=("$@")

  if bashunit::parallel::is_enabled; then
    bashunit::runner::parse_result_parallel "$fn_name" "$execution_result" ${args+"${args[@]}"}
  else
    bashunit::runner::parse_result_sync "$fn_name" "$execution_result"
  fi
}

function bashunit::runner::parse_result_parallel() {
  local fn_name=$1
  shift
  local execution_result=$1
  # This runs once per test in every parallel worker, so avoid per-test forks:
  # derive the suite dir name with parameter expansion (no basename), only
  # mkdir when the dir is missing (first test of the file wins the race,
  # `-p` makes the losers no-ops), and name the result file by the per-suite
  # ordinal the dispatcher assigned — unique without forking mktemp or mv.
  local test_suite_base="${test_file##*/}"
  local test_suite_dir="${TEMP_DIR_PARALLEL_TEST_SUITE}/${test_suite_base%.sh}"
  [ -d "$test_suite_dir" ] || mkdir -p "$test_suite_dir"

  local unique_test_result_file="${test_suite_dir}/${_BASHUNIT_RUNNER_RESULT_ORDINAL}.result"

  bashunit::internal_log "[PARA]" "fn_name:$fn_name" "execution_result:$execution_result"

  bashunit::runner::parse_result_sync "$fn_name" "$execution_result"

  echo "$execution_result" >"$unique_test_result_file"
}

function bashunit::runner::parse_result_sync() {
  local fn_name=$1
  local execution_result=$2

  bashunit::runner::extract_result_counts "$execution_result"

  bashunit::internal_log "[SYNC]" "fn_name:$fn_name" "execution_result:$execution_result"

  _BASHUNIT_ASSERTIONS_PASSED=$((_BASHUNIT_ASSERTIONS_PASSED + _BASHUNIT_RUNNER_COUNTS_PASSED_OUT))
  _BASHUNIT_ASSERTIONS_FAILED=$((_BASHUNIT_ASSERTIONS_FAILED + _BASHUNIT_RUNNER_COUNTS_FAILED_OUT))
  _BASHUNIT_ASSERTIONS_SKIPPED=$((_BASHUNIT_ASSERTIONS_SKIPPED + _BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT))
  _BASHUNIT_ASSERTIONS_INCOMPLETE=$((_BASHUNIT_ASSERTIONS_INCOMPLETE + _BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT))
  _BASHUNIT_ASSERTIONS_SNAPSHOT=$((_BASHUNIT_ASSERTIONS_SNAPSHOT + _BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT))
  _BASHUNIT_TEST_EXIT_CODE=$((_BASHUNIT_TEST_EXIT_CODE + _BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT))

  bashunit::internal_log "result_summary" \
    "failed:$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT" \
    "passed:$_BASHUNIT_RUNNER_COUNTS_PASSED_OUT" \
    "skipped:$_BASHUNIT_RUNNER_COUNTS_SKIPPED_OUT" \
    "incomplete:$_BASHUNIT_RUNNER_COUNTS_INCOMPLETE_OUT" \
    "snapshot:$_BASHUNIT_RUNNER_COUNTS_SNAPSHOT_OUT" \
    "exit_code:$_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT"
}

function bashunit::runner::write_failure_result_output() {
  local test_file=$1
  local fn_name=$2
  local error_msg=$3
  local raw_output="${4:-}"

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_failed)
  fi

  local output_section=""
  if [ -n "$raw_output" ] && bashunit::env::is_show_output_on_failure_enabled; then
    output_section="\n    Output:\n$raw_output"
  fi

  local source_context=""
  if [ -n "$line_number" ] && [ -f "$test_file" ]; then
    source_context=$(bashunit::runner::get_failure_source_context \
      "$test_file" "$line_number")
  fi

  echo -e "$test_nr) $test_file:$line_number\n$error_msg$output_section$source_context" \
    >>"$FAILURES_OUTPUT_PATH"
}

function bashunit::runner::get_failure_source_context() {
  local file=$1
  local fn_line=$2

  # Read the file once (a bash builtin loop) instead of forking `sed` to fetch
  # each line and `grep` to test each line for the closing brace. The fork count
  # no longer grows with the function length.
  local line_text line_num=0 assert_lines="" stripped trimmed
  while IFS= read -r line_text || [ -n "$line_text" ]; do
    line_num=$((line_num + 1))
    # Skip everything up to and including the function definition line.
    if [ "$line_num" -le "$fn_line" ]; then
      continue
    fi
    # Stop at the closing brace of the function (a line that is only `}`).
    stripped="${line_text#"${line_text%%[![:space:]]*}"}"
    stripped="${stripped%"${stripped##*[![:space:]]}"}"
    if [ "$stripped" = "}" ]; then
      break
    fi
    # Collect lines containing assert calls
    case "$line_text" in
    *assert_* | *assert\ *)
      trimmed="${line_text#"${line_text%%[![:space:]]*}"}"
      assert_lines="${assert_lines}\n    ${_BASHUNIT_COLOR_FAINT}${line_num}:${_BASHUNIT_COLOR_DEFAULT} ${trimmed}"
      ;;
    esac
  done <"$file"

  if [ -n "$assert_lines" ]; then
    echo -e "\n    ${_BASHUNIT_COLOR_FAINT}Source:${_BASHUNIT_COLOR_DEFAULT}${assert_lines}"
  fi
}

function bashunit::runner::write_skipped_result_output() {
  local test_file=$1
  local fn_name=$2
  local output_msg=$3

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_skipped)
  fi

  echo -e "$test_nr) $test_file:$line_number\n$output_msg" >>"$SKIPPED_OUTPUT_PATH"
}

function bashunit::runner::write_incomplete_result_output() {
  local test_file=$1
  local fn_name=$2
  local output_msg=$3

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_incomplete)
  fi

  echo -e "$test_nr) $test_file:$line_number\n$output_msg" >>"$INCOMPLETE_OUTPUT_PATH"
}

function bashunit::runner::write_risky_result_output() {
  local test_file=$1
  local fn_name=$2

  local line_number
  line_number=$(bashunit::helper::get_function_line_number "$fn_name")

  local test_nr="*"
  if ! bashunit::parallel::is_enabled; then
    test_nr=$(bashunit::state::get_tests_risky)
  fi

  echo -e "$test_nr) $test_file:$line_number\nTest has no assertions (risky)" >>"$RISKY_OUTPUT_PATH"
}
