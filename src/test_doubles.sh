#!/bin/bash

declare -a MOCKED_FUNCTIONS=()

function unmock() {
  local command=$1

  for i in "${!MOCKED_FUNCTIONS[@]}"; do
    if [[ "${MOCKED_FUNCTIONS[$i]}" == "$command" ]]; then
      unset "MOCKED_FUNCTIONS[$i]"
      unset -f "$command"
      break
    fi
  done
}

function mock() {
  local command=$1
  shift

  if [[ $# -gt 0 ]]; then
    eval "function $command() { $* ; }"
  else
    eval "function $command() { echo \"$($CAT)\" ; }"
  fi

  export -f "${command?}"

  MOCKED_FUNCTIONS+=("$command")
}

function spy() {
  local command=$1
  local variable
  variable="$(helper::normalize_variable_name "$command")"

  export "${variable}_times"=0
  export "${variable}_params"

  eval "function $command() { ${variable}_params=(\"\$*\"); ((${variable}_times++)) || true; }"

  export -f "${command?}"

  MOCKED_FUNCTIONS+=("$command")
}

function assert_have_been_called() {
  local command=$1
  local variable
  variable="$(helper::normalize_variable_name "$command")"
  local actual
  actual="${variable}_times"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ${!actual} -eq 0 ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${command}" "to has been called" "once"
    return
  fi

  state::add_assertions_passed
}

function assert_have_been_called_with() {
  local expected=$1
  local command=$2
  local variable
  variable="$(helper::normalize_variable_name "$command")"
  local actual
  actual="${variable}_params"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$expected" != "${!actual}" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "but got " "${!actual}"
    return
  fi

  state::add_assertions_passed
}

function assert_have_been_called_times() {
  local expected=$1
  local command=$2
  local variable
  variable="$(helper::normalize_variable_name "$command")"
  local actual
  actual="${variable}_times"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  if [[ -z "${!actual-}" && $expected -ne 0 || ${!actual-0} -ne $expected ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${command}" "to has been called" "${expected} times"
    return
  fi

  state::add_assertions_passed
}
