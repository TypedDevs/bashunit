#!/usr/bin/env bash

##
# Marks the running test skipped. The label is read `depth` frames up the
# stack, so every public helper states its own distance to the test function.
# Arguments: $1 - reason (optional), $2 - stack depth of the test function
##
function bashunit::skip::__mark() {
  local reason=${1-}
  local depth=${2:-2}
  local label
  # :- so a helper called from outside a test (a sourced file's top level) does
  # not abort the run with an unbound FUNCNAME entry under strict mode.
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[$depth]:-}")"

  bashunit::console_results::print_skipped_test "${label}" "${reason}"

  bashunit::state::add_assertions_skipped
}

##
# Marks the test skipped and ends it.
#
# A Bash 3.0 function cannot return on its caller's behalf, but the test body
# runs inside the capture subshell (bashunit::runner::execute_test_body), whose
# EXIT trap encodes the assertion counters and the captured output. Exiting
# here therefore ends the test with its counters and reports intact, which is
# what `bashunit::skip && return` did by hand at every call site.
#
# Called from inside a test's own `$(...)`, it ends that subshell only, as any
# exit would.
# Arguments: $1 - reason (optional)
##
function bashunit::skip::__mark_and_stop() {
  bashunit::skip::__mark "${1-}" 3
  exit 0
}

function bashunit::skip() {
  bashunit::skip::__mark "${1-}" 2
}

##
# Skips the test when the condition succeeds. The condition is evaluated as a
# shell command, so it can carry arguments:
#
#   bashunit::skip_if "[ -n \"${CI:-}\" ]" "flaky on CI"
#
# Arguments: $1 - condition, $2 - reason (optional)
##
function bashunit::skip_if() {
  local condition=${1-}
  local reason=${2-}

  if eval "$condition"; then
    bashunit::skip::__mark_and_stop "$reason"
  fi
}

##
# Skips the test unless the condition succeeds; the mirror of skip_if.
# Arguments: $1 - condition, $2 - reason (optional)
##
function bashunit::skip_unless() {
  local condition=${1-}
  local reason=${2-}

  if eval "$condition"; then
    return 0
  fi

  bashunit::skip::__mark_and_stop "$reason"
}

##
# Skips the test unless every given command resolves, naming the first one
# missing as the reason.
# Arguments: $@ - commands
##
function bashunit::skip_unless_command() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      bashunit::skip::__mark_and_stop "requires $cmd"
    fi
  done
}

##
# Skips the test on the given operating system: windows, macos or linux.
# An unrecognised name is a usage error, reported through the Error channel,
# rather than a test that silently never skips.
# Arguments: $1 - os, $2 - reason (optional)
##
function bashunit::skip_on() {
  local os=${1-}
  local reason=${2-}
  local matches=false

  case "$os" in
  windows)
    if bashunit::check_os::is_windows; then
      matches=true
    fi
    ;;
  macos)
    if bashunit::check_os::is_macos; then
      matches=true
    fi
    ;;
  linux)
    if bashunit::check_os::is_linux; then
      matches=true
    fi
    ;;
  *)
    # Same machine-detectable channel as an assertion misuse, so the runner
    # reports it as an Error instead of letting a typo pass for a green test.
    bashunit::assert::usage_error_detail "bashunit::skip_on" \
      "accepts windows, macos or linux, got '$os'"
    return 1
    ;;
  esac

  if [ "$matches" = true ]; then
    bashunit::skip::__mark_and_stop "$reason"
  fi
}

function bashunit::todo() {
  local pending=${1-}
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  bashunit::console_results::print_incomplete_test "${label}" "${pending}"

  bashunit::state::add_assertions_incomplete
}
