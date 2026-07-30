#!/usr/bin/env bash

##
# Returns to the directory bashunit was started from, undoing any `cd` a test
# file performed in `set_up_before_script` (#532).
#
# A failure here is not recoverable: every later test file is discovered and
# sourced through a path relative to this directory, so silently staying put
# would drop the remaining files from the run without a single error. Abort
# loudly instead.
#
# Arguments: $1 (optional) directory to restore, defaults to BASHUNIT_WORKING_DIR
##
function bashunit::runner::restore_workdir() {
  local target="${1:-${BASHUNIT_WORKING_DIR:-}}"
  if cd "$target" 2>/dev/null; then
    return 0
  fi

  printf "%sError: cannot restore the working directory '%s'. Aborting run.%s\n" \
    "${_BASHUNIT_COLOR_FAILED:-}" "$target" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
  exit 1
}

##
# Whether the running Bash has a reliable `set -o pipefail`. Bash 3.0 shipped a
# broken pipefail (a failing pipeline can wrongly report success), which makes
# `--strict` unsound; on 3.0 we fall back to `set -eu` without pipefail.
# Returns: 0 when pipefail is reliable (Bash >= 3.1), 1 otherwise.
##
function bashunit::runner::_supports_reliable_pipefail() {
  if [ "${BASH_VERSINFO[0]:-0}" -gt 3 ]; then
    return 0
  fi
  [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 1 ]
}

# Caches BASHUNIT_COVERAGE into _BASHUNIT_COVERAGE_ON ("1"|"0") so hot-path checks
# avoid a function dispatch per call. Call once after arg parsing; tests that
# toggle BASHUNIT_COVERAGE mid-run must call this again to refresh.
function bashunit::runner::sync_coverage_flag() {
  if [ "${BASHUNIT_COVERAGE-}" = "true" ]; then
    _BASHUNIT_COVERAGE_ON=1
  else
    _BASHUNIT_COVERAGE_ON=0
  fi
}

function bashunit::runner::source_login_shell_profiles() {
  # shellcheck disable=SC1091
  [ -f /etc/profile ] && source /etc/profile 2>/dev/null || true
  # shellcheck disable=SC1090
  [ -f ~/.bash_profile ] && source ~/.bash_profile 2>/dev/null || true
  # shellcheck disable=SC1090
  [ -f ~/.bash_login ] && source ~/.bash_login 2>/dev/null || true
  # shellcheck disable=SC1090
  [ -f ~/.profile ] && source ~/.profile 2>/dev/null || true
}

function bashunit::runner::export_test_identity() {
  local test_file=$1
  local fn_name=$2
  bashunit::helper::generate_id "$fn_name"
  export BASHUNIT_CURRENT_TEST_ID="$_BASHUNIT_HELPER_ID_OUT"
  bashunit::runner::resolve_test_location "$test_file" "$fn_name"
  export _BASHUNIT_TEST_LOCATION
  if [ "${_BASHUNIT_COVERAGE_ON:-0}" = 1 ]; then
    export _BASHUNIT_COVERAGE_CURRENT_TEST_FILE="$test_file"
    export _BASHUNIT_COVERAGE_CURRENT_TEST_FN="$fn_name"
  fi
}

##
# Resolves "<test_file>:<line>" for a test function and writes it into the
# global _BASHUNIT_TEST_LOCATION, using `declare -F` under `extdebug` to read
# the definition line. Falls back to just the file path when the line cannot be
# determined. Bash 3.0+ compatible. Writes a global slot (no extra subshell).
# Arguments: $1 test file, $2 function name
##
function bashunit::runner::resolve_test_location() {
  local test_file=$1
  local fn_name=$2

  # Enable extdebug only inside the command-substitution subshell so it never
  # leaks into the parent shell — globally toggling extdebug interferes with
  # `set -e`/DEBUG-trap behavior under --strict.
  local def line=""
  def="$(shopt -s extdebug; declare -F "$fn_name" 2>/dev/null)" || true

  # `declare -F` (with extdebug) prints "<name> <line> <file>".
  if [ -n "$def" ]; then
    line=${def#* }
    line=${line%% *}
  fi

  if [ -n "$line" ]; then
    _BASHUNIT_TEST_LOCATION="${test_file}:${line}"
  else
    _BASHUNIT_TEST_LOCATION="$test_file"
  fi
}

# Writes the interpolated test-function name into _BASHUNIT_RUNNER_INTERP_OUT.
# Arguments: $1 fn_name, $@ test arguments
function bashunit::runner::apply_interpolated_title() {
  local fn_name=$1
  shift

  # Only "::N::"-style names interpolate; skip the capture fork for the rest.
  case "$fn_name" in
  *::*) ;;
  *)
    bashunit::state::reset_current_test_interpolated_function_name
    _BASHUNIT_RUNNER_INTERP_OUT=$fn_name
    return
    ;;
  esac

  local interpolated
  interpolated="$(bashunit::helper::interpolate_function_name "$fn_name" "$@")"
  if [ "$interpolated" != "$fn_name" ]; then
    bashunit::state::set_current_test_interpolated_function_name "$interpolated"
  else
    bashunit::state::reset_current_test_interpolated_function_name
  fi
  _BASHUNIT_RUNNER_INTERP_OUT=$interpolated
}

# Per-test duration is consumed by --profile, --verbose, report files, and the
# execution-time display. When none are active we can skip the clock reads,
# which matters when the clock forks an interpreter (#765).
function bashunit::runner::needs_test_duration() {
  bashunit::env::is_profile_enabled && return 0
  bashunit::env::is_verbose_enabled && return 0
  bashunit::reports::is_enabled && return 0
  bashunit::env::is_show_execution_time_enabled && return 0
  return 1
}
