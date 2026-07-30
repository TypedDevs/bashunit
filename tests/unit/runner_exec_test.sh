#!/usr/bin/env bash

# --- result-line layout contract ---------------------------------------------
# The "##KEY=value##" subshell result record has two writers:
# bashunit::state::export_subshell_context (canonical) and the timeout-path copy
# bashunit::runner::build_timeout_result. They live in different files, so a
# field added to one silently shortens the record the other emits, and every
# reader (runner::extract_result_counts, state::aggregate_parallel_results)
# then mis-parses timed-out tests. Folding the two writers into one function
# would put a call on the per-test hot path that #762/#764 deliberately
# stripped; pinning the layout costs nothing at runtime and fails the moment
# the copies diverge.

# Echoes the ordered field keys of a "##KEY=value##..." record, one per line.
function result_line_field_keys() {
  local rest="$1"
  local key
  while [ -n "$rest" ]; do
    case "$rest" in
    *"##"*) rest="${rest#*##}" ;;
    *) break ;;
    esac
    key="${rest%%=*}"
    case "$key" in
    "$rest") continue ;;
    esac
    printf '%s\n' "$key"
  done
}

function test_timeout_result_uses_the_same_field_layout_as_the_state_writer() {
  local canonical
  canonical="$(bashunit::state::export_subshell_context)"
  local timeout_line
  timeout_line="$(bashunit::runner::build_timeout_result)"

  assert_same \
    "$(result_line_field_keys "$canonical")" \
    "$(result_line_field_keys "$timeout_line")"
}

function test_timeout_result_reports_the_conventional_timed_out_exit_code() {
  bashunit::runner::extract_result_counts "$(bashunit::runner::build_timeout_result)"

  assert_same "124" "$_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT"
  assert_same "0" "$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT"
  assert_same "0" "$_BASHUNIT_RUNNER_COUNTS_PASSED_OUT"
}
