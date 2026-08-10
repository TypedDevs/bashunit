#!/usr/bin/env bash

# The run lifecycle: dispatch to the runner, aggregate, report, clean up.

function bashunit::main::exec_tests() {
  local filter=$1
  local tag_filter="${2:-}"
  local exclude_tag_filter="${3:-}"
  shift 3

  # Bash 3.0 compatible: collect files into array
  local test_files
  local test_files_count=0
  local _line
  while IFS= read -r _line; do
    [ -z "$_line" ] && continue
    test_files[test_files_count]="$_line"
    test_files_count=$((test_files_count + 1))
  done < <(bashunit::helper::load_test_files "$filter" "$@")

  bashunit::internal_log "exec_tests" "filter:$filter" "files:${test_files[*]:-}"

  if [ "$test_files_count" -eq 0 ]; then
    printf "%sError: At least one file path is required.%s\n" "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::console_header::print_help
    exit 1
  fi

  # Keep only the test files git reports as touched since the ref. This narrows
  # after the "at least one path" guard on purpose: reaching zero files here is
  # a real answer, so it renders "No tests found" and exits 1, the same shape an
  # empty shard has, instead of the guard's "path is required" help dump.
  if bashunit::env::is_changed_enabled; then
    local _changed_ref
    _changed_ref=$(bashunit::helper::git_changed_ref)
    local -a _changed_files=()
    local _changed_file
    while IFS= read -r _changed_file; do
      [ -z "$_changed_file" ] && continue
      _changed_files[${#_changed_files[@]}]="$_changed_file"
    done < <(bashunit::helper::git_filter_changed "$_changed_ref" "${test_files[@]}")
    test_files=("${_changed_files[@]+"${_changed_files[@]}"}")
    test_files_count=${#test_files[@]}
    bashunit::internal_log "changed" "ref:$_changed_ref" "files:$test_files_count"
  fi

  # Split the suite across runners: keep the files whose position matches this
  # shard (round-robin), so all shards together cover the whole suite with no
  # overlap. An empty shard (more shards than files) is valid and runs nothing.
  if bashunit::env::is_shard_enabled; then
    local _shard_index _shard_total
    _shard_index=$(bashunit::env::shard_index)
    _shard_total=$(bashunit::env::shard_total)
    local -a _sharded=()
    local _i=0
    while [ "$_i" -lt "$test_files_count" ]; do
      if [ "$((_i % _shard_total))" -eq "$((_shard_index - 1))" ]; then
        _sharded[${#_sharded[@]}]="${test_files[_i]}"
      fi
      _i=$((_i + 1))
    done
    test_files=("${_sharded[@]+"${_sharded[@]}"}")
    test_files_count=${#test_files[@]}
    bashunit::internal_log "shard" "index:$_shard_index" "total:$_shard_total" "files:$test_files_count"
  fi

  # Trap SIGINT (Ctrl-C) and call the cleanup function
  trap 'bashunit::main::cleanup' SIGINT
  trap '[ $? -eq $EXIT_CODE_STOP_ON_FAILURE ] && bashunit::main::handle_stop_on_failure_sync' EXIT

  # Resolve parallel mode once now that --parallel/--no-parallel are parsed, so
  # the per-test is_enabled reads a global instead of re-checking env + OS.
  bashunit::parallel::resolve_enabled

  if bashunit::env::is_parallel_run_enabled && ! bashunit::parallel::is_enabled; then
    printf "%sWarning: Parallel tests are supported on macOS, Ubuntu, Alpine and Windows.\n" \
      "${_BASHUNIT_COLOR_INCOMPLETE}"
    printf "On other systems --parallel is not enabled due to inconsistent results,\n"
    printf "particularly involving race conditions.%s " "${_BASHUNIT_COLOR_DEFAULT}"
    printf "%sFallback using --no-parallel%s\n" "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  fi

  if bashunit::parallel::is_enabled; then
    bashunit::parallel::init
  fi

  # --list is a query: stdout must be nothing but test ids, so the banner and
  # the seed line are suppressed and the run header never prints (#1007).
  if bashunit::env::is_list_enabled; then
    :
  elif bashunit::env::is_tap_output_enabled; then
    printf "TAP version 13\n"
  else
    bashunit::console_header::print_version_with_env "$filter" "${test_files[@]}"
  fi

  # Resolve the shuffle seed once (generating one if absent) so it can be printed
  # for replay and inherited by parallel test-file subshells.
  if bashunit::env::is_random_order_enabled; then
    if [ -z "${BASHUNIT_SEED:-}" ]; then
      BASHUNIT_SEED=$RANDOM
      export -n BASHUNIT_SEED
    fi
    if ! bashunit::env::is_tap_output_enabled && ! bashunit::env::is_list_enabled; then
      bashunit::console_header::print_random_order_seed "$BASHUNIT_SEED"
    fi
  fi

  if bashunit::env::is_verbose_enabled; then
    if bashunit::env::is_simple_output_enabled; then
      echo ""
    fi
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '#'
    printf "%s\n" "Filter:      ${filter:-None}"
    printf "%s\n" "Total files: ${#test_files[@]}"
    printf "%s\n" "Test files:"
    printf -- "- %s\n" "${test_files[@]}"
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '.'
    bashunit::env::print_verbose
    printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '#'
  fi

  bashunit::runner::load_test_files "$filter" "$tag_filter" "$exclude_tag_filter" "${test_files[@]}"

  # Nothing ran, so there are no results to render, no reports to write and no
  # rerun cache to update. An empty selection is a valid answer to a query, so
  # this exits 0 where a real run would exit 1 with "No tests found".
  if bashunit::env::is_list_enabled; then
    bashunit::runner::list_render_summary
    bashunit::env::cleanup_run_output_dir
    exit 0
  fi

  if bashunit::parallel::is_enabled; then
    wait
  fi

  if bashunit::parallel::is_enabled && bashunit::parallel::must_stop_on_failure; then
    printf "\r%sStop on failure enabled...%s\n" "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  fi

  if ! bashunit::env::is_tap_output_enabled; then
    bashunit::console_results::print_failing_tests_and_reset
    bashunit::console_results::print_risky_tests_and_reset
    bashunit::console_results::print_incomplete_tests_and_reset
    bashunit::console_results::print_skipped_tests_and_reset
  fi
  bashunit::console_results::render_result
  exit_code=$?

  # Rows first, and the Markdown summary before print_profile_and_reset below
  # removes the profile records that summary reads.
  bashunit::reports::load_spooled

  if [ -n "$BASHUNIT_REPORT_MD" ]; then
    bashunit::reports::generate_report_md "$BASHUNIT_REPORT_MD"
  elif bashunit::env::should_append_step_summary; then
    bashunit::reports::append_step_summary
  fi

  if bashunit::env::is_profile_enabled; then
    bashunit::console_results::print_profile_and_reset
  fi

  # Report only: it never touches exit_code, captured above. With no discovered
  # file the helper falls back to the working directory.
  if bashunit::env::is_snapshot_report_unused_enabled; then
    bashunit::snapshot::report_unused ${test_files[@]+"${test_files[@]}"}
  fi

  # To stdout, not to a file: GitHub reads workflow commands from the job log.
  # After load_spooled so a --parallel run annotates the rows its workers
  # spooled, which the parent would otherwise never have seen (#1004).
  if bashunit::env::should_print_gha_annotations; then
    bashunit::reports::print_gha_annotations all
  fi

  if [ -n "$BASHUNIT_LOG_JUNIT" ]; then
    bashunit::reports::generate_junit_xml "$BASHUNIT_LOG_JUNIT"
  fi

  if [ -n "$BASHUNIT_LOG_GHA" ]; then
    bashunit::reports::generate_gha_log "$BASHUNIT_LOG_GHA"
  fi

  if [ -n "$BASHUNIT_REPORT_HTML" ]; then
    bashunit::reports::generate_report_html "$BASHUNIT_REPORT_HTML"
  fi

  if [ -n "$BASHUNIT_REPORT_TAP" ]; then
    bashunit::reports::generate_report_tap "$BASHUNIT_REPORT_TAP"
  fi

  if [ -n "$BASHUNIT_REPORT_JSON" ]; then
    bashunit::reports::generate_report_json "$BASHUNIT_REPORT_JSON"
  fi

  # Generate coverage report if enabled
  if bashunit::env::is_coverage_enabled; then
    # Turn captured xtrace output into hit records (no-op for the trap engine)
    bashunit::coverage::finalize

    # Aggregate per-process coverage data from parallel runs
    if bashunit::parallel::is_enabled; then
      bashunit::coverage::aggregate_parallel
    fi

    bashunit::coverage::precompute_file_stats

    if bashunit::coverage::is_diff_enabled; then
      bashunit::coverage::report_diff
    else
      bashunit::coverage::report_text
    fi

    if [ -n "$BASHUNIT_COVERAGE_REPORT" ]; then
      bashunit::coverage::report_lcov "$BASHUNIT_COVERAGE_REPORT"
    fi

    if [ -n "$BASHUNIT_COVERAGE_REPORT_HTML" ]; then
      bashunit::coverage::report_html "$BASHUNIT_COVERAGE_REPORT_HTML"
    fi

    # Check minimum threshold
    if ! bashunit::coverage::check_threshold; then
      exit_code=1
    fi

    bashunit::coverage::cleanup
  fi

  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi

  # Persist this run's failing tests so a later --rerun-failed can replay them.
  bashunit::rerun::persist

  # The rerun cache is read from the run dir above, so clean up only after it.
  bashunit::env::cleanup_run_output_dir

  bashunit::internal_log "Finished tests" "exit_code:$exit_code"
  exit $exit_code
}

function bashunit::main::exec_benchmarks() {
  local filter=$1
  shift

  # Bash 3.0 compatible: collect files into array
  local bench_files
  local bench_files_count=0
  local _line
  while IFS= read -r _line; do
    [ -z "$_line" ] && continue
    bench_files[bench_files_count]="$_line"
    bench_files_count=$((bench_files_count + 1))
  done < <(bashunit::helper::load_bench_files "$filter" "$@")

  bashunit::internal_log "exec_benchmarks" "filter:$filter" "files:${bench_files[*]:-}"

  if [ "$bench_files_count" -eq 0 ]; then
    printf "%sError: At least one file path is required.%s\n" "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::console_header::print_help
    exit 1
  fi

  bashunit::console_header::print_version_with_env "$filter" "${bench_files[@]}"

  bashunit::runner::load_bench_files "$filter" "${bench_files[@]}"

  bashunit::benchmark::print_results

  bashunit::internal_log "Finished benchmarks"
}

function bashunit::main::cleanup() {
  printf "%sCaught Ctrl-C, killing all child processes...%s\n" \
    "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  # Kill all child processes of this script
  pkill -P $$
  bashunit::cleanup_script_temp_files
  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi
  bashunit::env::cleanup_run_output_dir
  exit 1
}

function bashunit::main::handle_stop_on_failure_sync() {
  printf "\n%sStop on failure enabled...%s\n" "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  bashunit::console_results::print_failing_tests_and_reset
  bashunit::console_results::print_risky_tests_and_reset
  bashunit::console_results::print_incomplete_tests_and_reset
  bashunit::console_results::print_skipped_tests_and_reset
  bashunit::console_results::render_result
  if bashunit::env::is_profile_enabled; then
    bashunit::console_results::print_profile_and_reset
  fi
  bashunit::cleanup_script_temp_files
  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi
  bashunit::env::cleanup_run_output_dir
  exit 1
}

