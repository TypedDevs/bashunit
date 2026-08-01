#!/usr/bin/env bash

# The assert_have_been_called* family, asserting on what a spy recorded.

function assert_have_been_called() {
  local command=$1
  bashunit::spy::times_to_slot "$command"
  local times=$_BASHUNIT_SPY_TIMES_OUT
  local label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [ "$_BASHUNIT_SPY_REGISTERED_OUT" = false ]; then
    bashunit::spy::fail_unregistered "$command" "$label"
    return
  fi

  if [ "$times" -eq 0 ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command"
    bashunit::console_results::print_failed_test "${label}" "${command}" "to have been called" "once" \
      "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  bashunit::state::add_assertions_passed
}


function assert_have_been_called_with() {
  local command=$1
  shift

  local index=""
  # A trailing all-digits arg selects the nth recorded call. Pure-bash glob
  # avoids forking echo+grep on every assertion.
  case "${!#}" in
  '' | *[!0-9]*) ;;
  *)
    index=${!#}
    set -- "${@:1:$#-1}"
    ;;
  esac

  local expected="$*"

  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  if [ -z "${!file_var-}" ]; then
    bashunit::spy::fail_unregistered "$command" "$label"
    return
  fi

  # One pass yields both the compared line and the total, which the failure
  # message needs — and costs no fork, unlike the tail/sed it replaces.
  bashunit::spy::read_call_to_slots "${!file_var-}" "$index"
  local raw=${_BASHUNIT_SPY_CALL_OUT%%$'\x1e'*}
  local total=$_BASHUNIT_SPY_CALL_TOTAL_OUT

  if [ "$expected" != "$raw" ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command"
    bashunit::console_results::print_failed_test "$label" "$expected" "but got " "$raw" \
      "compared" "$(bashunit::spy::compared_call "$index" "$total")" \
      "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  bashunit::state::add_assertions_passed
}


function assert_have_been_called_with_args() {
  local command=$1
  shift

  bashunit::spy::serialize_args_to_slot "$@"
  local expected=$_BASHUNIT_SPY_SERIALIZED_OUT

  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  if [ -z "${!file_var-}" ]; then
    bashunit::spy::fail_unregistered "$command" "$label"
    return
  fi

  bashunit::spy::read_call_to_slots "${!file_var-}"
  local actual=""
  case "$_BASHUNIT_SPY_CALL_OUT" in
  *$'\x1e'*) actual=${_BASHUNIT_SPY_CALL_OUT#*$'\x1e'} ;;
  esac

  if [ "$expected" != "$actual" ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command" args
    bashunit::console_results::print_failed_test "$label" \
      "${expected//$'\x1f'/ }" "but got " "${actual//$'\x1f'/ }" \
      "compared" "$(bashunit::spy::compared_call "" "$_BASHUNIT_SPY_CALL_TOTAL_OUT")" \
      "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  bashunit::state::add_assertions_passed
}


function assert_have_been_called_with_any() {
  local command=$1
  shift
  local expected="$*"

  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  if [ -z "${!file_var-}" ]; then
    bashunit::spy::fail_unregistered "$command" "$label"
    return
  fi

  local total=0
  local found=false
  local line
  if [ -f "${!file_var}" ]; then
    while IFS= read -r line; do
      total=$((total + 1))
      if [ "${line%%$'\x1e'*}" = "$expected" ]; then
        found=true
        break
      fi
    done <"${!file_var}"
  fi

  if [ "$found" = false ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command"
    bashunit::console_results::print_failed_test "$label" "$expected" \
      "not found in any of" "${total} calls" "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  bashunit::state::add_assertions_passed
}


function assert_have_been_called_times() {
  local expected_count=$1
  local command=$2
  bashunit::spy::times_to_slot "$command"
  local times=$_BASHUNIT_SPY_TIMES_OUT
  local label="${3:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [ "$_BASHUNIT_SPY_REGISTERED_OUT" = false ]; then
    bashunit::spy::fail_unregistered "$command" "$label"
    return
  fi

  if [ "$times" -ne "$expected_count" ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command"
    bashunit::console_results::print_failed_test "${label}" "${command}" \
      "to have been called" "${expected_count} times" \
      "actual" "${times} times" "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  bashunit::state::add_assertions_passed
}


function assert_have_been_called_nth_with() {
  local nth=$1
  local command=$2
  shift 2
  local expected="$*"

  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
  local label
  label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  bashunit::spy::times_to_slot "$command"
  local times=$_BASHUNIT_SPY_TIMES_OUT

  if [ "$_BASHUNIT_SPY_REGISTERED_OUT" = false ]; then
    bashunit::spy::fail_unregistered "$command" "$label"
    return
  fi

  if [ "$nth" -gt "$times" ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command"
    bashunit::console_results::print_failed_test "${label}" \
      "expected call" "at index ${nth} but" "only called ${times} times" \
      "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  local line=""
  if [ -f "${!file_var-}" ]; then
    line=$(sed -n "${nth}p" "${!file_var}" 2>/dev/null || true)
  fi

  local raw
  IFS=$'\x1e' read -r raw _ <<<"$line" || true

  if [ "$expected" != "$raw" ]; then
    bashunit::state::add_assertions_failed
    bashunit::spy::call_log_to_slot "$command"
    bashunit::console_results::print_failed_test "${label}" \
      "$expected" "but got " "$raw" "" "" "$_BASHUNIT_SPY_CALL_LOG_OUT"
    return
  fi

  bashunit::state::add_assertions_passed
}


function assert_not_called() {
  local command=$1
  local label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  assert_have_been_called_times 0 "$command" "$label"
}
