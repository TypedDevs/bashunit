#!/usr/bin/env bash

##
# Appends a profiling record (duration, test name, file) to PROFILE_OUTPUT_PATH.
# Uses a tab-separated, append-only line so it aggregates correctly across the
# subshells spawned by parallel runs.
# Arguments: $1 duration (ms), $2 test name, $3 test file
##
function bashunit::runner::record_profile() {
  local duration=$1
  local test_name=$2
  local test_file=$3
  printf '%s\t%s\t%s\n' "$duration" "$test_name" "$test_file" >>"$PROFILE_OUTPUT_PATH"
}

##
# Honours --stop-on-failure once a test has been recorded as failed. A parallel
# worker raises the shared flag file (the dispatcher checks it between tests)
# rather than exiting, since exiting would only kill the worker. A sequential
# run exits with EXIT_CODE_STOP_ON_FAILURE, which main.sh's EXIT trap turns
# into the final summary. No-op when the flag is off.
##
function bashunit::runner::halt_if_stop_on_failure() {
  bashunit::env::is_stop_on_failure_enabled || return 0

  if bashunit::parallel::is_enabled; then
    bashunit::parallel::mark_stop_on_failure
  else
    exit "$EXIT_CODE_STOP_ON_FAILURE"
  fi
}

# Writes the detected runtime-error message (empty when none) into
# _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT. Return-slot form avoids a per-test fork
# on the hot path (#764).
# Arguments: $1 runtime_output
function bashunit::runner::detect_runtime_error() {
  local runtime_output=$1
  _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT=""
  case "$runtime_output" in
  *"command not found"* | *"unbound variable"* | *"permission denied"* | \
    *"no such file or directory"* | *"syntax error"* | *"bad substitution"* | \
    *"division by 0"* | *"cannot allocate memory"* | *"bad file descriptor"* | \
    *"segmentation fault"* | *"illegal option"* | *"argument list too long"* | \
    *"readonly variable"* | *"missing keyword"* | *"killed"* | \
    *"cannot execute binary file"* | *"invalid arithmetic operator"* | \
    *"ambiguous redirect"* | *"integer expression expected"* | \
    *"too many arguments"* | *"value too great"* | \
    *"not a valid identifier"* | *"unexpected EOF"*)
    local runtime_error="${runtime_output#*: }"
    _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT="${runtime_error//$'\n'/}"
    ;;
  esac
}

##
# Maps a process exit code to a human-readable description when it indicates the
# test was killed by a signal (128 + signal) or timed out. Returns an empty
# string for ordinary exit codes. Bash 3.0+ compatible.
# Arguments: $1 exit code
##
function bashunit::runner::classify_kill_signal() {
  local code=$1

  case "$code" in
  124) printf 'Timed out (killed by `timeout`)' ;;
  130) printf 'Interrupted (SIGINT)' ;;
  137) printf 'Killed (SIGKILL — out of memory or forced termination)' ;;
  143) printf 'Terminated (SIGTERM — e.g. a timeout)' ;;
  *)
    # Generic "killed by signal N" for other 128+N codes (signals 1..64)
    case "$code" in
    '' | *[!0-9]*) return 0 ;;
    esac
    if [ "$code" -gt 128 ] && [ "$code" -le 192 ]; then
      printf 'Killed by signal %s' "$((code - 128))"
    fi
    ;;
  esac
}

function bashunit::runner::print_verbose_test_summary() {
  local test_file=$1
  local fn_name=$2
  local duration=$3
  local test_execution_result=$4

  if bashunit::env::is_simple_output_enabled; then
    echo ""
  fi

  printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '='
  printf "%s\n" "File:     $test_file"
  printf "%s\n" "Function: $fn_name"
  printf "%s\n" "Duration: $duration ms"
  local raw_text=${test_execution_result%%##ASSERTIONS_*}
  [ -n "$raw_text" ] && printf "%s" "Raw text: $raw_text"
  printf "%s\n" "##ASSERTIONS_${test_execution_result#*##ASSERTIONS_}"
  printf '%*s\n' "$TERMINAL_WIDTH" '' | tr ' ' '-'
}

function bashunit::runner::render_running_file_header() {
  local script="$1"
  local force="${2:-false}"

  bashunit::internal_log "Running file" "$script"

  if [ "$force" != true ] && bashunit::parallel::is_enabled; then
    return
  fi

  # Suppress file headers in failures-only mode
  if bashunit::env::is_failures_only_enabled; then
    return
  fi

  # Suppress file headers in no-progress mode
  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_tap_output_enabled; then
    printf "# %s\n" "$script"
  elif ! bashunit::env::is_simple_output_enabled; then
    if bashunit::env::is_verbose_enabled; then
      printf "\n${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" "Running $script"
    else
      printf "${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}\n" "Running $script"
    fi
  elif bashunit::env::is_verbose_enabled; then
    printf "\n\n${_BASHUNIT_COLOR_BOLD}%s${_BASHUNIT_COLOR_DEFAULT}" "Running $script"
  fi
}
