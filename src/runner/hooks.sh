#!/usr/bin/env bash

function bashunit::runner::cleanup_on_exit() {
  local test_file="$1"
  local exit_code="$2"

  # Disable coverage trap before cleanup to avoid interference
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::disable_trap
  fi

  set +e

  # Settle a bashunit::assert_once marker the test body left open, before
  # tear_down runs its own assertions and before the counters are exported.
  bashunit::assert::once_flush

  # Detect unexpected subshell exit during set_up (Issue #611).
  # When 'source' of a non-existent file fails under set -eE, the ERR trap
  # does not fire. On macOS Bash 3.2, $? is 0 in the EXIT trap; on Linux
  # Bash 5.x, $? is 1. In both cases the hook failure is not recorded.
  # Additionally, the stdout redirect from execute_test_hook leaks into the
  # EXIT trap. Restore stdout from saved FD 5 so export_subshell_context
  # output reaches test_execution_result.
  # shellcheck disable=SC2031
  if [ "${_BASHUNIT_SETUP_COMPLETED:-true}" != "true" ]; then
    exec 1>&5
    if [ "$exit_code" -eq 0 ]; then
      exit_code=1
    fi
    if [ -z "${_BASHUNIT_TEST_HOOK_FAILURE:-}" ]; then
      bashunit::state::set_test_hook_failure "set_up"
      bashunit::state::set_test_hook_message "Hook 'set_up' failed unexpectedly (e.g., source of non-existent file)"
    fi
  fi

  # Don't use || here - it disables ERR trap in the entire call chain
  bashunit::runner::run_tear_down "$test_file"
  local teardown_status=$?
  bashunit::runner::clear_mocks
  bashunit::cleanup_testcase_temp_files

  if [ $teardown_status -ne 0 ]; then
    bashunit::state::set_test_exit_code "$teardown_status"
  else
    bashunit::state::set_test_exit_code "$exit_code"
  fi

  bashunit::state::export_subshell_context
}

function bashunit::runner::record_file_hook_failure() {
  local hook_name="$1"
  local test_file="$2"
  local hook_output="$3"
  local status="$4"
  local render_header="${5:-false}"

  if [ "$render_header" = true ]; then
    bashunit::runner::render_running_file_header "$test_file" true
  fi

  if [ -z "$hook_output" ]; then
    hook_output="Hook '$hook_name' failed with exit code $status"
  fi

  bashunit::state::add_tests_failed
  bashunit::console_results::print_error_test "$hook_name" "$hook_output"
  local _normalized_hook
  _normalized_hook="$(bashunit::helper::normalize_test_function_name "$hook_name")"
  bashunit::reports::add_test_failed "$test_file" "$_normalized_hook" 0 0 "$hook_output"
  bashunit::runner::write_failure_result_output "$test_file" "$hook_name" "$hook_output"

  return "$status"
}

function bashunit::runner::execute_file_hook() {
  local hook_name="$1"
  local test_file="$2"
  local render_header="${3:-false}"

  declare -F "$hook_name" >/dev/null 2>&1 || return 0

  local hook_output=""
  local status=0
  local hook_output_file
  hook_output_file=$(bashunit::temp_file "${hook_name}_output")

  # Enable errtrace to catch any failing command in the hook.
  # Using -E (errtrace) without -e (errexit) prevents the main process from
  # exiting on source failures (Bash 3.2 doesn't trigger ERR trap with -eE).
  # The ERR trap saves the exit status to a global variable, cleans up shell
  # options, and returns from the hook function to prevent subsequent commands
  # from executing.
  # Variables set before the failure are preserved since we don't use a subshell.
  _BASHUNIT_HOOK_ERR_STATUS=0
  set -E
  if bashunit::env::is_strict_mode_enabled; then
    set -uo pipefail
  fi
  # The trap returns from the function where the failure occurred (early-exit
  # semantics for intermediate failing commands) — but only when that frame is
  # NOT this executor: on Bash >= 4 the trap also fires HERE when the hook call
  # itself returns non-zero, and an unconditional return skipped
  # record_file_hook_failure entirely (silent failures, off-by-one counts, #836).
  # shellcheck disable=SC2154
  trap '_BASHUNIT_HOOK_ERR_STATUS=$?
    if [ "${FUNCNAME[0]:-}" != "bashunit::runner::execute_file_hook" ]; then
      set +Eu +o pipefail
      trap - ERR
      return $_BASHUNIT_HOOK_ERR_STATUS
    fi' ERR

  {
    "$hook_name"
  } >"$hook_output_file" 2>&1
  # Real exit status of the hook, read from $? (this function runs without -e,
  # so a failing compound does not exit). The ERR-trap global alone is not
  # enough: a hook ending in a failing `cmd && var=x` guard returns non-zero
  # without ever firing the trap (&& lists are ERR-exempt), which silently
  # swallowed the failure (#836).
  status=$?
  if [ "$status" -eq 0 ]; then
    status=$_BASHUNIT_HOOK_ERR_STATUS
  fi

  trap - ERR
  set +Eu +o pipefail

  if [ -f "$hook_output_file" ]; then
    hook_output=""
    local line
    while IFS= read -r line; do
      [ -z "$hook_output" ] && hook_output="$line" || hook_output="$hook_output"$'\n'"$line"
    done <"$hook_output_file"
    rm -f "$hook_output_file"
  fi

  if [ $status -ne 0 ]; then
    bashunit::runner::record_file_hook_failure "$hook_name" "$test_file" "$hook_output" "$status" "$render_header"
    return $status
  fi

  if [ -n "$hook_output" ] && bashunit::env::is_verbose_enabled; then
    printf "%s\n" "$hook_output"
  fi

  return 0
}

function bashunit::runner::run_set_up() {
  local _test_file="${1-}"
  bashunit::internal_log "run_set_up"
  bashunit::runner::execute_test_hook 'set_up'
}

function bashunit::runner::run_set_up_before_script() {
  local test_file="$1"
  bashunit::internal_log "run_set_up_before_script"

  # Check if hook exists first
  if ! declare -F "set_up_before_script" >/dev/null 2>&1; then
    return 0
  fi

  local start_time
  start_time=$(bashunit::clock::now)

  # Enable coverage trap to attribute lines executed during set_up_before_script
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::enable_trap
  fi

  # Execute the hook (render_header=false since header is already rendered)
  bashunit::runner::execute_file_hook 'set_up_before_script' "$test_file" false
  local status=$?

  # Disable coverage trap after hook execution
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::disable_trap
  fi

  local end_time
  end_time=$(bashunit::clock::now)
  local duration_ns=$((end_time - start_time))
  local duration_ms=$((duration_ns / 1000000))

  # Print completion message only if hook succeeded
  if [ $status -eq 0 ]; then
    bashunit::console_results::print_hook_completed "set_up_before_script" "$duration_ms"
  fi

  return $status
}

function bashunit::runner::run_tear_down() {
  local _test_file="${1-}"
  bashunit::internal_log "run_tear_down"
  bashunit::runner::execute_test_hook 'tear_down'
}

function bashunit::runner::execute_test_hook() {
  local hook_name="$1"

  declare -F "$hook_name" >/dev/null 2>&1 || return 0

  local hook_output=""
  local status=0
  local hook_output_file
  hook_output_file=$(bashunit::temp_file "${hook_name}_output")

  # Enable errtrace to catch any failing command in the hook.
  # Using -E (errtrace) without -e (errexit) prevents the subshell from
  # exiting on source failures (Bash 3.2 doesn't trigger ERR trap with -eE).
  # The ERR trap saves the exit status to a global variable, cleans up shell
  # options, and returns from the hook function to prevent subsequent commands
  # from executing.
  # Variables set before the failure are preserved since we don't use a subshell.
  _BASHUNIT_HOOK_ERR_STATUS=0
  set -E
  if bashunit::env::is_strict_mode_enabled; then
    set -uo pipefail
  fi
  # See the twin comment in execute_file_hook: conditional return keeps the
  # early-exit semantics for intermediate failures without silently returning
  # from THIS executor when the trap re-fires here on Bash >= 4 (#836).
  # shellcheck disable=SC2154
  trap '_BASHUNIT_HOOK_ERR_STATUS=$?
    if [ "${FUNCNAME[0]:-}" != "bashunit::runner::execute_test_hook" ]; then
      set +Eu +o pipefail
      trap - ERR
      return $_BASHUNIT_HOOK_ERR_STATUS
    fi' ERR

  {
    "$hook_name"
  } >"$hook_output_file" 2>&1
  # Real hook status from $?; the trap global alone misses failing
  # `cmd && var=x` guards (&& lists are ERR-exempt) (#836).
  status=$?
  if [ "$status" -eq 0 ]; then
    status=$_BASHUNIT_HOOK_ERR_STATUS
  fi

  trap - ERR
  set +Eu +o pipefail

  if [ -f "$hook_output_file" ]; then
    hook_output=""
    local line
    while IFS= read -r line; do
      [ -z "$hook_output" ] && hook_output="$line" || hook_output="$hook_output"$'\n'"$line"
    done <"$hook_output_file"
    rm -f "$hook_output_file"
  fi

  if [ $status -ne 0 ]; then
    local message="$hook_output"
    if [ -n "$hook_output" ]; then
      printf "%s" "$hook_output"
    else
      message="Hook '$hook_name' failed with exit code $status"
      printf "%s\n" "$message" >&2
    fi
    bashunit::runner::record_test_hook_failure "$hook_name" "$message" "$status"
    return "$status"
  fi

  if [ -n "$hook_output" ]; then
    printf "%s" "$hook_output"
  fi

  return 0
}

function bashunit::runner::record_test_hook_failure() {
  local hook_name="$1"
  local hook_message="$2"
  local status="$3"

  if [ -n "$_BASHUNIT_TEST_HOOK_FAILURE" ]; then
    return "$status"
  fi

  bashunit::state::set_test_hook_failure "$hook_name"
  bashunit::state::set_test_hook_message "$hook_message"

  return "$status"
}

function bashunit::runner::clear_mocks() {
  if [ "${#_BASHUNIT_MOCKED_FUNCTIONS[@]}" -eq 0 ]; then
    return
  fi

  local i
  for i in "${!_BASHUNIT_MOCKED_FUNCTIONS[@]}"; do
    bashunit::unmock "${_BASHUNIT_MOCKED_FUNCTIONS[$i]:-}"
  done
}

function bashunit::runner::run_tear_down_after_script() {
  local test_file="$1"
  bashunit::internal_log "run_tear_down_after_script"

  # Check if hook exists first
  if ! declare -F "tear_down_after_script" >/dev/null 2>&1; then
    # Add blank line after tests if no tear_down hook
    if ! bashunit::env::is_simple_output_enabled &&
      ! bashunit::env::is_failures_only_enabled &&
      ! bashunit::env::is_no_progress_enabled &&
      ! bashunit::parallel::is_enabled; then
      echo ""
    fi
    return 0
  fi

  local start_time
  start_time=$(bashunit::clock::now)

  # Enable coverage trap to attribute lines executed during tear_down_after_script
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::enable_trap
  fi

  # Execute the hook
  bashunit::runner::execute_file_hook 'tear_down_after_script' "$test_file"
  local status=$?

  # Disable coverage trap after hook execution
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    bashunit::coverage::disable_trap
  fi

  local end_time
  end_time=$(bashunit::clock::now)
  local duration_ns=$((end_time - start_time))
  local duration_ms=$((duration_ns / 1000000))

  # Print completion message only if hook succeeded
  if [ $status -eq 0 ]; then
    bashunit::console_results::print_hook_completed "tear_down_after_script" "$duration_ms"
  fi

  # Add blank line after tear_down output
  if ! bashunit::env::is_simple_output_enabled &&
    ! bashunit::env::is_failures_only_enabled &&
    ! bashunit::env::is_no_progress_enabled &&
    ! bashunit::parallel::is_enabled; then
    echo ""
  fi

  return $status
}

##
# Unset a file's test functions once the file has been processed.
#
# Test files are sourced into the main shell, and their functions used to stay
# defined for the whole run: every test's $() subshell then forked an
# ever-growing shell, making multi-file runs quadratic in file count (#829).
# In parallel mode the file's workers have already forked (with their own copy
# of the functions) by the time this runs, so unsetting here is race-free.
# Arguments: $1 - whitespace-separated test function names
##
function bashunit::runner::clean_script_test_functions() {
  local IFS=$' \t\n'
  local fn
  for fn in $1; do
    unset -f "$fn" 2>/dev/null || true
  done
}

function bashunit::runner::clean_set_up_and_tear_down_after_script() {
  bashunit::internal_log "clean_set_up_and_tear_down_after_script"
  bashunit::helper::unset_if_exists 'set_up'
  bashunit::helper::unset_if_exists 'tear_down'
  bashunit::helper::unset_if_exists 'set_up_before_script'
  bashunit::helper::unset_if_exists 'tear_down_after_script'
}
