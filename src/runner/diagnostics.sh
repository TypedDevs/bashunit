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
# Sets _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT when a line of $1 is a real bash
# diagnostic: one carrying the source-and-line prefix as well as a known
# phrase. Split out so a text miss falls through to the exit-code check rather
# than returning from the caller.
##
function bashunit::runner::_scan_diagnostic_lines() {
  local runtime_output=$1
  # A phrase alone is not enough. The capture also carries bashunit's own
  # rendering of the failure, and a test whose subject is error handling will
  # legitimately quote one of these strings as data -- both used to be misread
  # as runtime errors and reported twice, as Failed and as Error, for one cause.
  # Requiring the prefix on the same line separates what the shell said from what
  # we said about it; bashunit's own output never carries it.
  local line
  while IFS= read -r line; do
    case "$line" in
    *": line "[0-9]*": "*) ;;
    *) continue ;;
    esac

    case "$line" in
    *"command not found"* | *"unbound variable"* | *"permission denied"* | \
      *"no such file or directory"* | *"syntax error"* | *"bad substitution"* | \
      *"division by 0"* | *"bad file descriptor"* | \
      *"illegal option"* | *"argument list too long"* | \
      *"readonly variable"* | *"missing keyword"* | \
      *"cannot execute binary file"* | *"invalid arithmetic operator"* | \
      *"ambiguous redirect"* | *"integer expression expected"* | \
      *"too many arguments"* | *"value too great"* | \
      *"not a valid identifier"* | *"unexpected EOF"*)
      # Extract from the whole capture, not the matched line: the message shape
      # (leading source stripped, newlines removed) is pinned by
      # tests/unit/runner/diagnostics_test.sh.
      local runtime_error="${runtime_output#*: }"
      _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT="${runtime_error//$'\n'/}"
      return
      ;;
    esac
  done <<EOF
$runtime_output
EOF
}

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
# _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT and display-safe output into
# _BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT. Return-slot form avoids a per-test fork
# on the hot path (#764).
# Arguments: $1 runtime_output
function bashunit::runner::detect_runtime_error() {
  local runtime_output=$1
  local exit_code=${2:-0}
  _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT=""
  _BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT=$runtime_output

  local usage_prefix="bashunit: assertion usage error: "
  local usage_marker=$'\n'"$usage_prefix"
  local usage_before=""
  local usage_rest=""
  local usage_found=false
  case "$runtime_output" in
  "$usage_prefix"*)
    usage_rest=${runtime_output#"$usage_prefix"}
    usage_found=true
    ;;
  *"$usage_marker"*)
    usage_before=${runtime_output%%"$usage_marker"*}
    usage_rest=${runtime_output#*"$usage_marker"}
    usage_found=true
    ;;
  esac

  if [ "$usage_found" = true ]; then
    local usage_error=${usage_rest%%$'\n'*}
    local usage_after=""
    if [ "$usage_rest" != "$usage_error" ]; then
      usage_after=${usage_rest#*$'\n'}
    fi
    _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT=$usage_error
    if [ -n "$usage_before" ] && [ -n "$usage_after" ]; then
      _BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT="$usage_before
$usage_after"
    elif [ -n "$usage_before" ]; then
      _BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT=$usage_before
    else
      _BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT=$usage_after
    fi
    return
  fi

  # Conditions the shell reports without a source-and-line prefix, because they
  # come from job control rather than the parser. Matched anywhere in the
  # capture, as before.
  case "$runtime_output" in
  *"killed"* | *"segmentation fault"* | *"cannot allocate memory"*)
    local runtime_error="${runtime_output#*: }"
    _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT="${runtime_error//$'\n'/}"
    return
    ;;
  esac

  # Everything else is a diagnostic bash emits with its source and line
  # ("file.sh: line 12: foo: command not found"). The cheap gate first: most
  # failing tests contain none of these phrases and pay one glob.
  case "$runtime_output" in
  *"command not found"* | *"unbound variable"* | *"permission denied"* | \
    *"no such file or directory"* | *"syntax error"* | *"bad substitution"* | \
    *"division by 0"* | *"bad file descriptor"* | \
    *"illegal option"* | *"argument list too long"* | \
    *"readonly variable"* | *"missing keyword"* | \
    *"cannot execute binary file"* | *"invalid arithmetic operator"* | \
    *"ambiguous redirect"* | *"integer expression expected"* | \
    *"too many arguments"* | *"value too great"* | \
    *"not a valid identifier"* | *"unexpected EOF"*)
    bashunit::runner::_scan_diagnostic_lines "$runtime_output"
    if [ -n "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT" ]; then
      return
    fi
    ;;
  esac


  # Last resort, and locale-independent. Everything above matches English text,
  # but bash translates its diagnostics -- under es_ES a missing command reads
  # "orden no encontrada" and matches nothing, so a genuine failure-to-run used
  # to be reported as a plain assertion failure.
  #
  # These two codes carry the same fact without any text: the shell reserves 127
  # for "could not find it" and 126 for "found it, could not run it". Consulted
  # only after the text scan draws a blank, so English behaviour -- including the
  # more specific message it produces -- is unchanged.
  case "$exit_code" in
  127) _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT="command not found (exit code 127)" ;;
  126) _BASHUNIT_RUNNER_RUNTIME_ERROR_OUT="not executable (exit code 126)" ;;
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
  elif bashunit::env::is_machine_output_enabled; then
    return
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
