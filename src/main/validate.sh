#!/usr/bin/env bash

# Input validation shared by every subcommand parser: unknown options, integer and path checks, shard parsing.

##
# Prints an "unknown option" error and exits non-zero.
# Arguments: $1 - the offending argument, $2 - subcommand to name in the hint
##
function bashunit::main::abort_unknown_option() {
  printf "%sError: unknown option '%s'. Run 'bashunit %s --help' to list the available options.%s\n" \
    "${_BASHUNIT_COLOR_FAILED}" "$1" "$2" "${_BASHUNIT_COLOR_DEFAULT}" >&2
  exit 1
}

##
# Exits non-zero unless the value is a non-negative integer.
# Arguments: $1 - value, $2 - the setting name to quote in the error
##
function bashunit::main::require_non_negative_int_or_exit() {
  case "$1" in
  '' | *[!0-9]*)
    printf "%sError: %s must be a non-negative integer, got '%s'.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "$2" "$1" "${_BASHUNIT_COLOR_DEFAULT}" >&2
    exit 1
    ;;
  esac
}

##
# Exits non-zero unless the path can be written: either it already exists and is
# writable, or its parent directory exists and is writable. Reports are produced
# after the suite has finished, so an unwritable destination used to surface as a
# raw redirect error on a run that had already reported success (#875).
# Arguments: $1 - path, $2 - the setting name to quote in the error
##
function bashunit::main::require_writable_path_or_exit() {
  local path=$1
  local parent=${1%/*}
  [ "$parent" = "$1" ] && parent="."
  [ -z "$parent" ] && parent="/"

  if [ -e "$path" ]; then
    [ -w "$path" ] && return 0
  elif [ -d "$parent" ] && [ -w "$parent" ]; then
    return 0
  fi

  printf "%sError: %s cannot be written: '%s'.%s\n" \
    "${_BASHUNIT_COLOR_FAILED}" "$2" "$path" "${_BASHUNIT_COLOR_DEFAULT}" >&2
  exit 1
}

##
# Validates the resolved configuration and exits non-zero on a bad value.
# Runs after flag parsing so it covers both the flags and the BASHUNIT_* env
# vars, which bypass the parser entirely. The numeric settings are compared with
# `[ -lt ]`, which errors instead of returning false on a non-integer operand: the
# job-slot poll looped forever and the rest silently dropped the setting (#873).
##
function bashunit::main::validate_config_or_exit() {
  if [ "${BASHUNIT_PARALLEL_JOBS:-0}" != "0" ]; then
    bashunit::main::require_non_negative_int_or_exit \
      "${BASHUNIT_PARALLEL_JOBS}" "BASHUNIT_PARALLEL_JOBS (--jobs)"
  fi
  bashunit::main::require_non_negative_int_or_exit \
    "${BASHUNIT_RETRY:-0}" "BASHUNIT_RETRY (--retry)"
  bashunit::main::require_non_negative_int_or_exit \
    "${BASHUNIT_TEST_TIMEOUT:-0}" "BASHUNIT_TEST_TIMEOUT (--test-timeout)"
  # Empty is the documented "no minimum" default, so only a set value is checked.
  if [ -n "${BASHUNIT_COVERAGE_MIN:-}" ]; then
    bashunit::main::require_non_negative_int_or_exit \
      "${BASHUNIT_COVERAGE_MIN}" "BASHUNIT_COVERAGE_MIN (--coverage-min)"
  fi
  # Env-only (no CLI flag). Compared with `[ -ge ]` in
  # bashunit::coverage::get_coverage_class, which errors instead of returning
  # false on a non-integer operand, leaking a raw shell error into the
  # coverage report and silently mis-bucketing every file's class (#879).
  bashunit::main::require_non_negative_int_or_exit \
    "${BASHUNIT_COVERAGE_THRESHOLD_LOW:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW}" \
    "BASHUNIT_COVERAGE_THRESHOLD_LOW"
  bashunit::main::require_non_negative_int_or_exit \
    "${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH}" \
    "BASHUNIT_COVERAGE_THRESHOLD_HIGH"

  if [ -n "${BASHUNIT_SEED:-}" ]; then
    bashunit::main::require_non_negative_int_or_exit "${BASHUNIT_SEED}" "BASHUNIT_SEED (--seed)"
  fi

  # BASHUNIT_SHARD_INDEX/BASHUNIT_SHARD_TOTAL set directly (e.g. via .bashunitrc)
  # bypass bashunit::main::set_shard_or_exit's parsing, which only runs on the
  # --shard flag path. Left unchecked, a non-numeric or zero total reached the
  # raw arithmetic in main/run.sh as a "division by 0" shell error, and an
  # out-of-range index silently produced "No tests found" instead of a clear
  # message -- the same failure shape this function already closed for other
  # settings (#873, #879).
  if bashunit::env::is_shard_enabled; then
    bashunit::main::require_non_negative_int_or_exit \
      "${BASHUNIT_SHARD_INDEX}" "BASHUNIT_SHARD_INDEX"
    bashunit::main::require_non_negative_int_or_exit \
      "${BASHUNIT_SHARD_TOTAL}" "BASHUNIT_SHARD_TOTAL"
    if [ "$BASHUNIT_SHARD_TOTAL" -lt 1 ] || [ "$BASHUNIT_SHARD_INDEX" -lt 1 ] ||
      [ "$BASHUNIT_SHARD_INDEX" -gt "$BASHUNIT_SHARD_TOTAL" ]; then
      printf "%sError: BASHUNIT_SHARD_INDEX/BASHUNIT_SHARD_TOTAL must satisfy 1 <= index <= total.%s\n" \
        "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}" >&2
      exit 1
    fi
  fi

  local _report_var _report_path
  for _report_var in BASHUNIT_LOG_JUNIT BASHUNIT_LOG_GHA BASHUNIT_REPORT_HTML \
    BASHUNIT_REPORT_TAP BASHUNIT_REPORT_JSON; do
    _report_path=${!_report_var:-}
    if [ -n "$_report_path" ]; then
      bashunit::main::require_writable_path_or_exit "$_report_path" "$_report_var"
    fi
  done

  # Only TAP is implemented; an unrecognised name used to fall back to the
  # default renderer without a word, so `--output tpa` looked like it worked.
  case "${BASHUNIT_OUTPUT_FORMAT:-}" in
  '' | tap) ;;
  *)
    printf "%sError: unsupported output format '%s' for --output. Supported: tap.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${BASHUNIT_OUTPUT_FORMAT}" "${_BASHUNIT_COLOR_DEFAULT}" >&2
    exit 1
    ;;
  esac
}

##
# Validates a `--shard <index>/<total>` spec and exports the parts, or prints an
# error and exits non-zero. Requires numeric index/total with 1 <= index <= total.
##
function bashunit::main::set_shard_or_exit() {
  local spec="${1:-}"
  local index total
  case "$spec" in
  */*)
    index="${spec%%/*}"
    total="${spec##*/}"
    ;;
  *)
    index=""
    total=""
    ;;
  esac
  case "$index" in '' | *[!0-9]*) index="" ;; esac
  case "$total" in '' | *[!0-9]*) total="" ;; esac

  if [ -z "$index" ] || [ -z "$total" ] ||
    [ "$total" -lt 1 ] || [ "$index" -lt 1 ] || [ "$index" -gt "$total" ]; then
    printf "%sError: --shard must be <index>/<total> with 1 <= index <= total (e.g. 1/4).%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}" >&2
    exit 1
  fi

  BASHUNIT_SHARD_INDEX="$index"
  export -n BASHUNIT_SHARD_INDEX
  BASHUNIT_SHARD_TOTAL="$total"
  export -n BASHUNIT_SHARD_TOTAL
}

#############################
# Subcommand: test
#############################
