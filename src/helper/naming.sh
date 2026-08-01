#!/usr/bin/env bash

# Resolving and normalising test-function and variable names.


#
# Walks up the call stack to find the first function that looks like a test function.
# A test function is one that starts with "test_" or "test" (camelCase).
# If no test function is found, falls back to the caller of the assertion function.
#
# @param $1 number Optional fallback depth (default: 2, i.e., the caller of the assertion)
#
# @return string The test function name, or fallback function name
#
_BASHUNIT_HELPER_TESTFN_OUT=""


#
# Return-slot variant of find_test_function_name: writes the result into
# _BASHUNIT_HELPER_TESTFN_OUT with no fork. Must be called at the SAME stack
# depth the echoing version would be captured at, so the fallback_depth default
# keeps pointing at the caller of the assertion (see the echoing wrapper below).
#
function bashunit::helper::find_test_function_name_to_slot() {
  local fallback_depth="${1:-2}"
  local i
  for ((i = 0; i < ${#FUNCNAME[@]}; i++)); do
    local fn="${FUNCNAME[$i]}"
    case "$fn" in
    test_* | test[A-Z]*)
      _BASHUNIT_HELPER_TESTFN_OUT=$fn
      return
      ;;
    esac
  done
  _BASHUNIT_HELPER_TESTFN_OUT=${FUNCNAME[$fallback_depth]:-}
}


function bashunit::helper::find_test_function_name() {
  local fallback_depth="${1:-2}"
  local i
  for ((i = 0; i < ${#FUNCNAME[@]}; i++)); do
    local fn="${FUNCNAME[$i]}"
    # Check if function starts with "test_" or "test" followed by uppercase.
    # Pure-bash globs avoid forking echo+grep on every call-stack frame (hot path).
    case "$fn" in
    test_* | test[A-Z]*)
      echo "$fn"
      return
      ;;
    esac
  done
  # No test function found, use fallback (caller of the assertion)
  # FUNCNAME[0] = bashunit::helper::find_test_function_name
  # FUNCNAME[1] = the assertion function (e.g., assert_same)
  # FUNCNAME[2] = caller of the assertion
  echo "${FUNCNAME[$fallback_depth]:-}"
}

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
#
_BASHUNIT_HELPER_NORMALIZED_OUT=""


#
# Return-slot variant of normalize_test_function_name: writes the result into
# _BASHUNIT_HELPER_NORMALIZED_OUT with no fork, removing the command-substitution
# fork at the (failure-path) call sites in the assertion layer.
#
# @param $1 string Eg: "test_some_logic_camelCase"
# @param $2 string Optional interpolated name
#
function bashunit::helper::normalize_test_function_name_to_slot() {
  local original_fn_name="${1-}"
  local interpolated_fn_name="${2-}"

  # Read the reserved-namespace state globals directly (the accessors just echo
  # them) to avoid a nested subshell fork on this per-test hot path (#764).
  local custom_title="${_BASHUNIT_TEST_TITLE:-}"
  if [ -n "$custom_title" ]; then
    _BASHUNIT_HELPER_NORMALIZED_OUT=$custom_title
    return
  fi

  if [ -z "${interpolated_fn_name-}" ]; then
    case "${original_fn_name}" in
    *"::"*)
      local state_interpolated_fn_name="${_BASHUNIT_CURRENT_TEST_INTERPOLATED_NAME:-}"

      if [ -n "$state_interpolated_fn_name" ]; then
        interpolated_fn_name="$state_interpolated_fn_name"
      fi
      ;;
    esac
  fi

  if [ -n "${interpolated_fn_name-}" ]; then
    original_fn_name="$interpolated_fn_name"
  fi

  local result

  # Remove the first "test_" prefix, if present
  result="${original_fn_name#test_}"
  # If no "test_" was removed (e.g., "testFoo"), remove the "test" prefix
  if [ "$result" = "$original_fn_name" ]; then
    result="${original_fn_name#test}"
  fi
  # Replace underscores with spaces
  result="${result//_/ }"
  # Capitalize the first letter (bash 3.0 compatible, no subprocess)
  local first_char="${result:0:1}"
  case "$first_char" in
  a) first_char='A' ;; b) first_char='B' ;; c) first_char='C' ;; d) first_char='D' ;;
  e) first_char='E' ;; f) first_char='F' ;; g) first_char='G' ;; h) first_char='H' ;;
  i) first_char='I' ;; j) first_char='J' ;; k) first_char='K' ;; l) first_char='L' ;;
  m) first_char='M' ;; n) first_char='N' ;; o) first_char='O' ;; p) first_char='P' ;;
  q) first_char='Q' ;; r) first_char='R' ;; s) first_char='S' ;; t) first_char='T' ;;
  u) first_char='U' ;; v) first_char='V' ;; w) first_char='W' ;; x) first_char='X' ;;
  y) first_char='Y' ;; z) first_char='Z' ;;
  esac
  result="${first_char}${result:1}"

  _BASHUNIT_HELPER_NORMALIZED_OUT=$result
}


#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
#
function bashunit::helper::normalize_test_function_name() {
  bashunit::helper::normalize_test_function_name_to_slot "${1-}" "${2-}"
  echo "$_BASHUNIT_HELPER_NORMALIZED_OUT"
}


function bashunit::helper::escape_single_quotes() {
  local value="$1"
  # shellcheck disable=SC1003
  echo "${value//\'/'\'\\''\'}"
}


function bashunit::helper::interpolate_function_name() {
  local function_name="$1"
  shift

  # Placeholders look like "::N::", so a name without "::" can never interpolate.
  # Short-circuit to skip the per-arg escape_single_quotes forks in that case.
  case "$function_name" in
  *::*) ;;
  *)
    echo "$function_name"
    return
    ;;
  esac

  local -a args
  local args_count=$#
  args=("$@")
  local result="$function_name"

  local i
  for ((i = 0; i < args_count; i++)); do
    local placeholder="::$((i + 1))::"
    # shellcheck disable=SC2155
    local value="$(bashunit::helper::escape_single_quotes "${args[$i]}")"
    value="'$value'"
    result="${result//${placeholder}/${value}}"
  done

  echo "$result"
}


# Return-slot variant of normalize_variable_name: writes the result into
# _BASHUNIT_HELPER_VARNAME_OUT with no fork, for hot-path callers that would
# otherwise capture it with a command substitution (e.g. snapshot path
# resolution, which calls it twice per assertion).
function bashunit::helper::normalize_variable_name_to_slot() {
  local input_string="$1"
  local normalized_string="${input_string//[^a-zA-Z0-9_]/_}"

  # First character must be alpha or underscore. Empty string also gets a `_`
  # prefix to satisfy the same identifier rule. Uses pure-bash globbing to
  # avoid a per-call grep fork (called once per test via generate_id).
  case "${normalized_string:0:1}" in
  [a-zA-Z_]) ;;
  *) normalized_string="_$normalized_string" ;;
  esac

  _BASHUNIT_HELPER_VARNAME_OUT=$normalized_string
}


function bashunit::helper::normalize_variable_name() {
  bashunit::helper::normalize_variable_name_to_slot "$1"
  builtin echo "$_BASHUNIT_HELPER_VARNAME_OUT"
}

# Provider map for the most recently scanned script. Scanning a file once and
# caching the test-function -> provider-function pairs replaces a per-test
# grep+sed fork with a pure-bash lookup on the hot path (issue #763).
_BASHUNIT_PROVIDER_MAP_SCRIPT=""
_BASHUNIT_PROVIDER_MAP_FNS=()
_BASHUNIT_PROVIDER_MAP_PROVIDERS=()
_BASHUNIT_PROVIDER_FN_OUT=""
# Set true when the scanned file carries the "# bashunit: no-parallel-tests"
# opt-out; detected in the same awk pass to avoid a per-file grep fork (#774).
_BASHUNIT_PROVIDER_MAP_NO_PARALLEL=false

