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
  # load_test_files falls back to BASHUNIT_DEFAULT_PATH when handed no files,
  # which is right only when the caller named no path. When they named one that
  # selected nothing, the fallback answered a question they did not ask -- with
  # a green run over the default suite (#1263). Skip discovery entirely there
  # and let the empty selection render as "No tests found".
  local _line
  if [ "$#" -gt 0 ] || [ "${_BASHUNIT_MAIN_PATHS_GIVEN:-false}" != true ]; then
    while IFS= read -r _line; do
      [ -z "$_line" ] && continue
      test_files[test_files_count]="$_line"
      test_files_count=$((test_files_count + 1))
    done < <(bashunit::helper::load_test_files "$filter" "$@")
  fi

  bashunit::internal_log "exec_tests" "filter:$filter" "files:${test_files[*]:-}"

  # Only when the caller named no path at all: with nothing to go on, the help
  # dump is the answer. A path they DID name that holds no test files is an
  # empty selection instead, so it falls through to "No tests found" -- the same
  # shape an empty shard has. Without that distinction zero files here meant
  # "use BASHUNIT_DEFAULT_PATH", and `bashunit empty_dir/` ran the default
  # suite and exited 0, reporting a pass for tests the caller never asked for
  # and never saw named (#1263).
  if [ "$test_files_count" -eq 0 ] && [ "${_BASHUNIT_MAIN_PATHS_GIVEN:-false}" != true ]; then
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

  # Builds the allowed-command directory once, in this shell: every test
  # subshell (and every --parallel worker) inherits its path.
  bashunit::sandbox::prepare

  # --list is a query: stdout must be nothing but test ids, so the banner and
  # the seed line are suppressed and the run header never prints (#1007).
  if bashunit::env::is_list_enabled; then
    :
  elif bashunit::env::is_tap_output_enabled; then
    printf "TAP version 13\n"
  elif bashunit::env::is_machine_output_enabled; then
    # json/junit print one document at the end; a banner would precede it.
    :
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
    if ! bashunit::env::is_machine_output_enabled && ! bashunit::env::is_list_enabled; then
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

  # Human output, so it must not reach a machine --output stream: under
  # `--parallel --stop-on-failure --output json` this line preceded the
  # document and the result did not parse, and under `--output junit` it
  # displaced the XML declaration. Snapshots strip carriage returns, which is
  # why the leading `\r` never showed up in one -- it is dropped here because
  # the spinner is already erased by the aggregation, where it was drawn.
  if bashunit::parallel::is_enabled && bashunit::parallel::must_stop_on_failure &&
    ! bashunit::env::is_machine_output_enabled; then
    printf "%sStop on failure enabled...%s\n" "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  fi

  if ! bashunit::env::is_machine_output_enabled; then
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

  # Coverage data is turned into numbers here rather than with the reports
  # below, because the Markdown summary quotes the same percentage and would
  # otherwise read it before the hit records exist — 0% for a covered run.
  if bashunit::env::is_coverage_enabled; then
    # Turn captured xtrace output into hit records (no-op for the trap engine)
    bashunit::coverage::finalize

    # Aggregate per-process coverage data from parallel runs
    if bashunit::parallel::is_enabled; then
      bashunit::coverage::aggregate_parallel
    fi

    bashunit::coverage::precompute_file_stats
  fi

  if [ -n "$BASHUNIT_REPORT_MD" ]; then
    bashunit::reports::generate_report_md "$BASHUNIT_REPORT_MD"
  elif bashunit::env::should_append_step_summary; then
    bashunit::reports::append_step_summary
  fi

  # The slowest-tests table is console rendering: it would sit in the middle of
  # a machine format's stdout.
  if bashunit::env::is_profile_enabled && ! bashunit::env::is_machine_output_enabled; then
    bashunit::console_results::print_profile_and_reset
  fi

  # Report only: it never touches exit_code, captured above. With no discovered
  # file the helper falls back to the working directory.
  if bashunit::env::is_snapshot_report_unused_enabled; then
    bashunit::snapshot::report_unused ${test_files[@]+"${test_files[@]}"}
  fi

  # In the parent, after the parallel results were aggregated: each worker
  # resolves its own snapshots, so the used-set only exists here (#1004).
  if bashunit::env::is_snapshot_prune_enabled; then
    bashunit::snapshot::prune_unused ${test_files[@]+"${test_files[@]}"}
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

  # The same writers, aimed at stdout instead of a file, so a pipeline needs no
  # temp file. Independent of the --report-* flags: both can be asked for in
  # one run. Only one format can be active, hence the elif.
  if bashunit::env::is_json_output_enabled; then
    bashunit::reports::print_report_json
  elif bashunit::env::is_junit_output_enabled; then
    bashunit::reports::print_junit_xml
  fi

  # Render the coverage reports; the data behind them was computed above.
  if bashunit::env::is_coverage_enabled; then
    if bashunit::coverage::is_diff_enabled; then
      if bashunit::env::is_machine_output_enabled; then
        # The pass still runs because it resolves the percentage
        # --coverage-min gates on; only its table is dropped, since stdout
        # belongs to the machine format.
        bashunit::coverage::report_diff >/dev/null
      else
        bashunit::coverage::report_diff
      fi
    elif ! bashunit::env::is_machine_output_enabled; then
      bashunit::coverage::report_text
    fi

    if [ -n "$BASHUNIT_COVERAGE_REPORT" ]; then
      bashunit::coverage::report_lcov "$BASHUNIT_COVERAGE_REPORT"
    fi

    if [ -n "$BASHUNIT_COVERAGE_REPORT_COBERTURA" ]; then
      bashunit::coverage::report_cobertura "$BASHUNIT_COVERAGE_REPORT_COBERTURA"
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

  # A path that does not exist survives find_files_recursive and
  # helper::load_bench_files, and is dropped silently by the `[ -f ]` guard
  # inside the loop -- so the count above is non-zero and the "at least one
  # file path" check never fires. The run then printed a header and exited 0,
  # green having measured nothing, which on a benchmark job is invisible
  # because the whole output is numbers (#1199). Same for a file that holds no
  # bench_ function. `test` reports "No tests found" and exits 1; match it.
  if [ "${#_BASHUNIT_BENCH_NAMES[@]}" -eq 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_RETURN_ERROR" " No benchmarks found " \
      "$_BASHUNIT_COLOR_DEFAULT"
    exit 1
  fi

  bashunit::benchmark::print_results

  # After the table, so a writer failure cannot swallow the results a human
  # was going to read anyway.
  if [ -n "${BASHUNIT_BENCH_REPORT_JSON:-}" ]; then
    bashunit::benchmark::report_json "$BASHUNIT_BENCH_REPORT_JSON"
  fi
  if [ -n "${BASHUNIT_BENCH_REPORT_JUNIT:-}" ]; then
    bashunit::benchmark::report_junit "$BASHUNIT_BENCH_REPORT_JUNIT"
  fi

  # Recording the new baseline before comparing against the old one: a run
  # meant to refresh the reference should write it whatever the verdict.
  if [ -n "${BASHUNIT_BENCH_BASELINE_UPDATE:-}" ]; then
    bashunit::benchmark::report_json "$BASHUNIT_BENCH_BASELINE_UPDATE"
  fi

  if [ -n "${BASHUNIT_BENCH_BASELINE:-}" ]; then
    bashunit::benchmark::baseline_load "$BASHUNIT_BENCH_BASELINE"
    if ! bashunit::benchmark::baseline_compare "${BASHUNIT_BENCH_BASELINE_TOLERANCE:-10}"; then
      exit 1
    fi
  fi

  # A file that failed to source, or whose set_up_before_script failed, is
  # recorded as a failure and printed -- but the exit code consulted only "no
  # benchmarks found" and the baseline gate, so a failure alongside a file that
  # did run left the run green. The error reached the human reading the log and
  # never reached CI, which is the worst of the two.
  if [ "$(bashunit::state::get_tests_failed)" -gt 0 ]; then
    exit 1
  fi

  bashunit::internal_log "Finished benchmarks"
}

function bashunit::main::cleanup() {
  # Back to the default disposition first: the teardown hook below is user code
  # and may never return, and an interrupt handler that cannot itself be
  # interrupted would leave no way out but SIGKILL. A second Ctrl-C now ends the
  # process. Safe to reset because SIGINT was trappable on entry, or this handler
  # would not be running.
  trap - INT
  printf "%sCaught Ctrl-C, killing all child processes...%s\n" \
    "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
  # Kill all child processes of this script
  pkill -P $$
  # After the kill, so the per-test tear_down that the test subshell's EXIT trap
  # runs comes first, as it does in a normal run. Before the temp-file sweep, so
  # a hook reading a bashunit::temp_file still finds it (#1323).
  bashunit::runner::run_pending_file_teardown || true
  bashunit::cleanup_script_temp_files
  if bashunit::parallel::is_enabled; then
    bashunit::parallel::cleanup
  fi
  bashunit::env::cleanup_run_output_dir
  exit 1
}

function bashunit::main::handle_stop_on_failure_sync() {
  # The exit that lands here came from inside the test loop, so the file's
  # teardown has not run. First, so the hook line follows the last test line as
  # it does in a normal run, and so a hook reading a bashunit::temp_file still
  # finds it (#1321).
  bashunit::runner::run_pending_file_teardown || true
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

