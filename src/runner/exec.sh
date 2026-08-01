#!/usr/bin/env bash

##
# Runs the given test functions of a script (sequentially, or one background
# worker per test under --parallel).
# Arguments: $1 script path, $2 space-separated test function names, already
# filter/tag/rerun-filtered by load_test_files (never empty: the caller skips
# the file when no function survives filtering).
##
function bashunit::runner::call_test_functions() {
  local script="$1"
  local cached_functions="${2:-}"
  local IFS=$' \t\n'
  local -a functions_to_run=()
  local functions_to_run_count=0

  local _fn
  for _fn in $cached_functions; do
    [ -z "$_fn" ] && continue
    functions_to_run[functions_to_run_count]="$_fn"
    functions_to_run_count=$((functions_to_run_count + 1))
  done

  # Randomize function order within this file. The seed is mixed with a stable
  # per-file value (cksum of the path) so different files get different orders
  # while staying reproducible for the resolved seed.
  if bashunit::env::is_random_order_enabled && [ "$functions_to_run_count" -gt 1 ]; then
    local _base _crc _fn_seed
    _base=$(bashunit::env::seed)
    _crc=$(printf '%s' "$script" | cksum | cut -d' ' -f1)
    _fn_seed=$(((_base + _crc) & 2147483647))
    local -a _shuffled_fns=()
    local _sfn
    while IFS= read -r _sfn; do
      [ -n "$_sfn" ] && _shuffled_fns[${#_shuffled_fns[@]}]=$_sfn
    done < <(printf '%s\n' "${functions_to_run[@]+"${functions_to_run[@]}"}" | bashunit::math::shuffle "$_fn_seed")
    functions_to_run=("${_shuffled_fns[@]+"${_shuffled_fns[@]}"}")
    functions_to_run_count=${#functions_to_run[@]}
  fi

  if [ "$functions_to_run_count" -le 0 ]; then
    return
  fi

  bashunit::helper::check_duplicate_functions "$script" || true

  local -a provider_data=()
  local provider_data_count=0
  local -a parsed_data=()
  local parsed_data_count=0
  # Monotonic within this file; names each parallel worker's .result file.
  local _test_ordinal=0

  # Scan the file once; per-test provider lookups below are pure-bash (#763).
  # The same pass also detects the no-parallel-tests opt-out (#774).
  bashunit::helper::build_provider_map "$script"

  local allow_test_parallel=true
  if [ "$_BASHUNIT_PROVIDER_MAP_NO_PARALLEL" = true ]; then
    allow_test_parallel=false
  fi

  # Pre-create the file's result dir before spawning test workers: they all
  # publish into it, and checking `[ -d ]` inside a worker races its siblings
  # (every worker would still pay the mkdir fork).
  if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
    bashunit::runner::parallel_suite_dir_to_slot "$script"
    mkdir -p "$_BASHUNIT_RUNNER_SUITE_DIR_OUT" 2>/dev/null || true
  fi

  for fn_name in "${functions_to_run[@]+"${functions_to_run[@]}"}"; do
    if bashunit::parallel::is_enabled && bashunit::parallel::must_stop_on_failure; then
      break
    fi

    # No data provider found: run once without forking to capture provider output.
    bashunit::helper::provider_for_function "$fn_name"
    if [ -z "$_BASHUNIT_PROVIDER_FN_OUT" ]; then
      if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
        bashunit::runner::wait_for_job_slot
        _test_ordinal=$((_test_ordinal + 1))
        _BASHUNIT_RUNNER_RESULT_ORDINAL=$_test_ordinal
        bashunit::runner::run_test "$script" "$fn_name" &
      else
        bashunit::runner::run_test "$script" "$fn_name"
      fi
      unset -v fn_name
      continue
    fi

    provider_data=()
    provider_data_count=0
    local line
    while IFS=" " read -r line; do
      [ -z "$line" ] && continue
      provider_data[provider_data_count]="$line"
      provider_data_count=$((provider_data_count + 1))
    done <<<"$(bashunit::helper::execute_function_if_exists "$_BASHUNIT_PROVIDER_FN_OUT")"

    # Execute the test function for each line of data
    local data
    for data in "${provider_data[@]+"${provider_data[@]}"}"; do
      parsed_data=()
      parsed_data_count=0
      local line
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        parsed_data[parsed_data_count]="$(bashunit::helper::decode_base64 "${line}")"
        parsed_data_count=$((parsed_data_count + 1))
      done <<<"$(bashunit::runner::parse_data_provider_args "$data")"
      if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
        bashunit::runner::wait_for_job_slot
        _test_ordinal=$((_test_ordinal + 1))
        _BASHUNIT_RUNNER_RESULT_ORDINAL=$_test_ordinal
        bashunit::runner::run_test "$script" "$fn_name" ${parsed_data+"${parsed_data[@]}"} &
      else
        bashunit::runner::run_test "$script" "$fn_name" ${parsed_data+"${parsed_data[@]}"}
      fi
    done
    unset -v fn_name
  done

  # Wait for all parallel tests within this file to complete
  if bashunit::parallel::is_enabled && [ "$allow_test_parallel" = true ]; then
    wait
  fi
}

# Result slots for the timeout-aware execution path (see run_with_timeout).
_BASHUNIT_RUNNER_EXEC_OUT=""
_BASHUNIT_RUNNER_TIMED_OUT="false"

##
# Runs a single test inside the capture subshell: sets up the EXIT trap that
# encodes assertion counts/exit code, runs set_up, applies the shell mode and
# finally invokes the test function. Meant to be called from a subshell (either
# the `$(...)` capture or a backgrounded job), so its `set`/`trap`/`exit` calls
# stay isolated. Emits the test stdout (with stderr merged) followed by the
# encoded context from cleanup_on_exit.
# Arguments: $1 test file, $2 function name, $@ test args
##
function bashunit::runner::execute_test_body() {
  local test_file=$1
  shift
  local fn_name=$1
  shift

  # Save subshell stdout to FD 5 so the EXIT trap can restore it.
  # When set -e kills the subshell during a redirected block in
  # execute_test_hook, the redirect leaks into the EXIT trap,
  # causing export_subshell_context output to be lost.
  exec 5>&1
  # shellcheck disable=SC2064
  # shellcheck disable=SC2154 # assigned inside the trap body, read by cleanup_on_exit (runner/hooks.sh)
  trap "exit_code=\$?; bashunit::runner::cleanup_on_exit \"$test_file\" \"\$exit_code\"" EXIT
  bashunit::state::initialize_assertions_count

  if bashunit::env::is_login_shell_enabled; then
    bashunit::runner::source_login_shell_profiles
  fi

  # Enable coverage tracking early to include set_up/tear_down hooks
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::enable_trap
  fi

  # Run set_up and capture exit code without || to preserve errexit behavior
  # shellcheck disable=SC2030
  _BASHUNIT_SETUP_COMPLETED=false
  local setup_exit_code=0
  bashunit::runner::run_set_up "$test_file"
  setup_exit_code=$?
  _BASHUNIT_SETUP_COMPLETED=true
  if [ $setup_exit_code -ne 0 ]; then
    exit $setup_exit_code
  fi

  # Apply shell mode setting for test execution
  if bashunit::env::is_strict_mode_enabled; then
    set -eu
    # Bash 3.0 ships a broken pipefail; only enable it where it is reliable.
    if bashunit::runner::_supports_reliable_pipefail; then
      set -o pipefail
    else
      set +o pipefail
    fi
  else
    set +euo pipefail
  fi

  # 2>&1: Redirects the std-error (FD 2) to the std-output (FD 1).
  # points to the original std-output.
  "$fn_name" "$@" 2>&1
}

##
# Prints an encoded subshell result for a test that timed out: empty assertion
# counters and exit code 124 (the conventional "timed out" code, already mapped
# by classify_kill_signal). The empty TEST_HOOK_MESSAGE/TITLE/OUTPUT fields would
# base64-encode to an empty string anyway, so the line is emitted directly rather
# than mutating the shared _BASHUNIT_* globals (it mirrors the layout produced by
# bashunit::state::export_subshell_context). Bash 3.0+ compatible.
##
function bashunit::runner::build_timeout_result() {
  printf '%s' "##ASSERTIONS_FAILED=0##ASSERTIONS_PASSED=0##ASSERTIONS_SKIPPED=0\
##ASSERTIONS_INCOMPLETE=0##ASSERTIONS_SNAPSHOT=0##TEST_EXIT_CODE=124\
##TEST_HOOK_FAILURE=##TEST_HOOK_MESSAGE=##TEST_TITLE=##TEST_OUTPUT=##"
}

##
# Runs the test body with a watchdog that kills it after BASHUNIT_TEST_TIMEOUT
# seconds. The body runs as a backgrounded job in its own process group (set -m)
# so the watchdog can SIGTERM/SIGKILL the whole tree — a hanging test usually
# blocks in a child process, which signalling the subshell alone cannot reach.
# Writes the captured result to _BASHUNIT_RUNNER_EXEC_OUT and "true"/"false" to
# _BASHUNIT_RUNNER_TIMED_OUT. Bash 3.0+ compatible (validated on Bash 3.2).
# Arguments: $1 test file, $2 function name, $@ test args
##
function bashunit::runner::run_with_timeout() {
  local test_file=$1
  shift
  local fn_name=$1
  shift
  local secs
  secs=$(bashunit::env::test_timeout_secs)

  # NOTE: these must NOT use bashunit::temp_file — that prefixes the current
  # test id, and cleanup_on_exit (run inside the test subshell) would unlink
  # them via cleanup_testcase_temp_files before we read them back here.
  local tmp_dir="${BASHUNIT_TEMP_DIR:-${TMPDIR:-/tmp}}"
  local out_file marker_file
  out_file="$("$MKTEMP" "$tmp_dir/bashunit_timeout_out.XXXXXXX")"
  marker_file="$("$MKTEMP" "$tmp_dir/bashunit_timeout_marker.XXXXXXX")"
  rm -f "$marker_file"

  # Both jobs run in their own process group (set -m) so each can be killed as a
  # whole tree. The body MUST run in an explicit ( ) subshell: a backgrounded { }
  # group does not run its EXIT trap on normal completion, which would drop the
  # encoded assertion context. The watchdog's fds are detached from the caller so
  # a lingering `sleep` can never hold a captured stdout pipe open.
  set -m
  (bashunit::runner::execute_test_body "$test_file" "$fn_name" "$@") >"$out_file" 2>&1 &
  local test_pid=$!
  (
    sleep "$secs"
    # Only a still-running test can have timed out. Without this guard a watchdog
    # that outlived a missed teardown (see below) would mark an already-finished
    # fast test as timed out.
    kill -0 "$test_pid" 2>/dev/null || exit 0
    : >"$marker_file"
    kill -TERM -"$test_pid" 2>/dev/null
    sleep 0.3
    kill -KILL -"$test_pid" 2>/dev/null
  ) </dev/null >/dev/null 2>&1 &
  local watchdog_pid=$!
  set +m

  wait "$test_pid" 2>/dev/null
  # Stop the watchdog by its pid AND its group. `set -m` does not reliably make a
  # backgrounded subshell a group leader in a non-interactive shell, so the
  # group-only kill intermittently misses, letting the watchdog sleep its full
  # timeout and fire against a test that already passed. The direct-pid signal is
  # always deliverable; the group signal also reaps the `sleep` child.
  kill -TERM "$watchdog_pid" 2>/dev/null
  kill -TERM -"$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null

  if [ -f "$marker_file" ]; then
    _BASHUNIT_RUNNER_TIMED_OUT="true"
    _BASHUNIT_RUNNER_EXEC_OUT="$(bashunit::runner::build_timeout_result)"
  else
    _BASHUNIT_RUNNER_TIMED_OUT="false"
    _BASHUNIT_RUNNER_EXEC_OUT="$(cat "$out_file" 2>/dev/null)"
  fi

  rm -f "$out_file" "$marker_file"
}

function bashunit::runner::run_test() {
  local start_time=0

  local test_file="$1"
  shift
  local fn_name="$1"
  shift

  bashunit::internal_log "Running test" "$fn_name" "$*"
  bashunit::runner::export_test_identity "$test_file" "$fn_name"

  bashunit::state::reset_test_title
  bashunit::runner::apply_interpolated_title "$fn_name" "$@"
  local interpolated_fn_name=$_BASHUNIT_RUNNER_INTERP_OUT
  local current_assertions_failed="$_BASHUNIT_ASSERTIONS_FAILED"
  local current_assertions_snapshot="$_BASHUNIT_ASSERTIONS_SNAPSHOT"
  local current_assertions_incomplete="$_BASHUNIT_ASSERTIONS_INCOMPLETE"
  local current_assertions_skipped="$_BASHUNIT_ASSERTIONS_SKIPPED"

  # (FD = File Descriptor)
  # Duplicate the current std-output (FD 1) and assigns it to FD 3.
  # This means that FD 3 now points to wherever the std-output was pointing.
  exec 3>&1

  local test_execution_result
  local timed_out="false"
  bashunit::env::resolve_retry_count
  local retry_max=$_BASHUNIT_RETRY_VALIDATED
  local retries_used=0
  local measure_duration=false
  bashunit::runner::needs_test_duration && measure_duration=true
  # Retry wraps ONLY execution: a failed attempt is judged from its encoded
  # result without committing, so the parse/report/counter path below still runs
  # exactly once (on the final attempt) and nothing is double-counted. Each fork
  # in --parallel retries itself before writing its single .result file.
  while :; do
    if [ "$measure_duration" = true ]; then
      bashunit::clock::now_to_slot
      start_time=$_BASHUNIT_CLOCK_NOW_OUT
    fi
    if bashunit::env::is_test_timeout_enabled; then
      bashunit::runner::run_with_timeout "$test_file" "$fn_name" "$@"
      test_execution_result="$_BASHUNIT_RUNNER_EXEC_OUT"
      timed_out="$_BASHUNIT_RUNNER_TIMED_OUT"
    else
      test_execution_result=$(bashunit::runner::execute_test_body "$test_file" "$fn_name" "$@")
    fi

    local attempt_runtime_output="${test_execution_result%%##ASSERTIONS_*}"
    bashunit::runner::detect_runtime_error "$attempt_runtime_output"
    local attempt_runtime_error=$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT
    bashunit::runner::extract_result_counts "$test_execution_result"
    # Mirror the commit-phase failure test exactly (runtime error, non-zero exit,
    # or a failed assertion); snapshot/incomplete/skipped/risky are not failures.
    if [ -z "$attempt_runtime_error" ] &&
      [ "$_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT" -eq 0 ] &&
      [ "$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT" -eq 0 ]; then
      break
    fi
    [ "$retries_used" -ge "$retry_max" ] && break
    retries_used=$((retries_used + 1))
  done

  # Closes FD 3, which was used temporarily to hold the original stdout.
  exec 3>&-

  local duration=0
  if [ "$measure_duration" = true ]; then
    bashunit::clock::now_to_slot
    local end_time=$_BASHUNIT_CLOCK_NOW_OUT
    duration=$(((end_time - start_time) / 1000000))
  fi

  if bashunit::env::is_profile_enabled; then
    bashunit::runner::record_profile "$duration" "$interpolated_fn_name" "$test_file"
  fi

  if bashunit::env::is_verbose_enabled; then
    bashunit::runner::print_verbose_test_summary \
      "$test_file" "$fn_name" "$duration" "$test_execution_result"
  fi

  bashunit::runner::decode_subshell_output "$test_execution_result"
  local subshell_output=$_BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT

  if [ -n "$subshell_output" ]; then
    bashunit::runner::extract_subshell_type "$subshell_output"
    local type=$_BASHUNIT_RUNNER_TYPE_OUT
    bashunit::runner::format_subshell_output "$subshell_output"
    subshell_output=$_BASHUNIT_RUNNER_OUTPUT_OUT
    if ! bashunit::env::is_failures_only_enabled; then
      bashunit::console_results::print_line "$type" "$subshell_output"
    fi
  fi

  # Reuse the final attempt's values (the loop always runs at least once and
  # its locals persist in this function scope), instead of recomputing and
  # forking detect_runtime_error a second time (#764).
  local runtime_output=$attempt_runtime_output
  local runtime_error=$attempt_runtime_error

  # parse_result accumulates _BASHUNIT_TEST_EXIT_CODE; reset it so each test's
  # exit code is read in isolation (a non-zero/timed-out test must not poison
  # the next one).
  _BASHUNIT_TEST_EXIT_CODE=0
  bashunit::runner::parse_result "$fn_name" "$test_execution_result" "$@"

  local test_exit_code="$_BASHUNIT_TEST_EXIT_CODE"

  bashunit::runner::compute_total_assertions "$test_execution_result"
  local total_assertions=$_BASHUNIT_RUNNER_TOTAL_OUT

  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_TITLE"
  local encoded_test_title=$_BASHUNIT_RUNNER_FIELD_OUT
  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_HOOK_FAILURE"
  local hook_failure=$_BASHUNIT_RUNNER_FIELD_OUT
  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_HOOK_MESSAGE"
  local encoded_hook_message=$_BASHUNIT_RUNNER_FIELD_OUT

  local test_title=""
  [ -n "$encoded_test_title" ] && test_title="$(bashunit::helper::decode_base64 "$encoded_test_title")"
  local hook_message=""
  [ -n "$encoded_hook_message" ] && hook_message="$(bashunit::helper::decode_base64 "$encoded_hook_message")"

  bashunit::set_test_title "$test_title"
  bashunit::helper::normalize_test_function_name_to_slot "$fn_name" "$interpolated_fn_name"
  local label=$_BASHUNIT_HELPER_NORMALIZED_OUT
  bashunit::state::reset_test_title
  bashunit::state::reset_current_test_interpolated_function_name

  local failure_label="$label"
  local failure_function="$fn_name"
  if [ -n "$hook_failure" ]; then
    bashunit::helper::normalize_test_function_name_to_slot "$hook_failure"
    failure_label=$_BASHUNIT_HELPER_NORMALIZED_OUT
    failure_function="$hook_failure"
  fi

  if [ -n "$runtime_error" ] || [ "$test_exit_code" -ne 0 ]; then
    bashunit::state::add_tests_failed
    bashunit::rerun::record "$test_file" "$fn_name"
    local error_message="$runtime_error"
    if [ -n "$hook_failure" ] && [ -n "$hook_message" ]; then
      error_message="$hook_message"
    elif [ -z "$error_message" ] && [ -n "$hook_message" ]; then
      error_message="$hook_message"
    fi

    # When the test was killed by a signal (or timed out), replace an empty or
    # generic "Killed" message with a specific cause.
    if [ -z "$hook_failure" ]; then
      local kill_message
      kill_message=$(bashunit::runner::classify_kill_signal "$test_exit_code")
      if [ -n "$kill_message" ]; then
        case "$error_message" in
        '' | *[Kk]illed* | *[Tt]erminated*) error_message="$kill_message" ;;
        esac
      fi
    fi

    # A test that exceeded BASHUNIT_TEST_TIMEOUT gets a clear, specific message.
    if [ "$timed_out" = "true" ]; then
      error_message="Test timed out after $(bashunit::env::test_timeout_secs)s"
    fi

    bashunit::console_results::print_error_test "$failure_function" "$error_message" "$runtime_output"
    bashunit::reports::add_test_failed "$test_file" "$failure_label" "$duration" "$total_assertions" "$error_message"
    bashunit::runner::write_failure_result_output "$test_file" "$failure_function" "$error_message" "$runtime_output"
    bashunit::internal_log "Test error" "$failure_label" "$error_message"

    bashunit::runner::halt_if_stop_on_failure
    return
  fi

  if [ "$current_assertions_failed" != "$_BASHUNIT_ASSERTIONS_FAILED" ]; then
    bashunit::state::add_tests_failed
    bashunit::rerun::record "$test_file" "$fn_name"
    bashunit::reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions" "$subshell_output"
    local assertion_runtime_output
    assertion_runtime_output="$(
      bashunit::runner::extract_assertion_runtime_output "$runtime_output" "$subshell_output"
    )"
    bashunit::runner::write_failure_result_output \
      "$test_file" "$fn_name" "$subshell_output" "$assertion_runtime_output"

    bashunit::internal_log "Test failed" "$label"

    bashunit::runner::halt_if_stop_on_failure
    return
  fi

  if [ "$current_assertions_snapshot" != "$_BASHUNIT_ASSERTIONS_SNAPSHOT" ]; then
    bashunit::state::add_tests_snapshot
    # In failures-only mode, suppress snapshot test output
    if ! bashunit::env::is_failures_only_enabled; then
      bashunit::console_results::print_snapshot_test "$label"
    fi
    bashunit::reports::add_test_snapshot "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::internal_log "Test snapshot" "$label"
    return
  fi

  if [ "$current_assertions_incomplete" != "$_BASHUNIT_ASSERTIONS_INCOMPLETE" ]; then
    bashunit::state::add_tests_incomplete
    bashunit::reports::add_test_incomplete "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_incomplete_result_output "$test_file" "$fn_name" "$subshell_output"
    bashunit::internal_log "Test incomplete" "$label"
    return
  fi

  if [ "$current_assertions_skipped" != "$_BASHUNIT_ASSERTIONS_SKIPPED" ]; then
    bashunit::state::add_tests_skipped
    bashunit::reports::add_test_skipped "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_skipped_result_output "$test_file" "$fn_name" "$subshell_output"
    bashunit::internal_log "Test skipped" "$label"
    return
  fi

  # Check for risky test (zero assertions)
  if [ "$total_assertions" -eq 0 ]; then
    if bashunit::env::is_fail_on_risky_enabled; then
      local risky_msg="Test has no assertions (risky)"
      bashunit::state::add_tests_failed
      bashunit::rerun::record "$test_file" "$fn_name"
      bashunit::console_results::print_error_test "$fn_name" "$risky_msg"
      bashunit::reports::add_test_failed "$test_file" "$label" "$duration" "$total_assertions" "$risky_msg"
      bashunit::runner::write_failure_result_output "$test_file" "$fn_name" "$risky_msg"
      bashunit::internal_log "Test failed (risky)" "$label"
      bashunit::runner::halt_if_stop_on_failure
      return
    fi
    bashunit::state::add_tests_risky
    if ! bashunit::env::is_failures_only_enabled; then
      bashunit::console_results::print_risky_test "${label}" "$duration"
    fi
    bashunit::reports::add_test_risky "$test_file" "$label" "$duration" "$total_assertions"
    bashunit::runner::write_risky_result_output "$test_file" "$fn_name"
    bashunit::internal_log "Test risky" "$label"
    return
  fi

  # A test that only passed after retrying is annotated so flakiness stays visible.
  _BASHUNIT_RETRY_NOTE=""
  if [ "$retries_used" -gt 0 ]; then
    _BASHUNIT_RETRY_NOTE=" (retry $retries_used/$retry_max)"
  fi
  # In failures-only mode, suppress successful test output
  if ! bashunit::env::is_failures_only_enabled; then
    if [ "$fn_name" = "$interpolated_fn_name" ]; then
      bashunit::console_results::print_successful_test "${label}" "$duration" "$@"
    else
      bashunit::console_results::print_successful_test "${label}" "$duration"
    fi
  fi
  _BASHUNIT_RETRY_NOTE=""
  bashunit::state::add_tests_passed
  bashunit::reports::add_test_passed "$test_file" "$label" "$duration" "$total_assertions"
  bashunit::internal_log "Test passed" "$label"
}
