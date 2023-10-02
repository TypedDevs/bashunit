#!/bin/bash

function mock() {
  local command=$1
  shift

  if [[ $# -gt 0 ]]; then
    eval "function $command() { $* ; }"
  else
    eval "function $command() { echo \"$($CAT)\" ; }"
  fi

  export -f "${command?}"
}

function spy() {
  local command=$1
  export "${command}_times"=0
  export "${command}_params"

  eval "function $command() { ${command}_params=(\"\$*\"); ((${command}_times++)) || true; }"

  export -f "${command?}"
}

function assert_have_been_called() {
  local command=$1
  local actual
  actual="${command}_times"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ${!actual} -eq 0 ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${command}" "to has been called" "once"
    return
  fi

  state::add_assertions_passed
}

function assert_have_been_called_with() {
  local expected=$1
  local command=$2
  local actual
  actual="${command}_params"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "${!actual}" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "but got" "${!actual}"
    return
  fi

  state::add_assertions_passed
}

function assert_have_been_called_times() {
  local expected=$1
  local command=$2
  local actual
  actual="${command}_times"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ${!actual} -ne $expected ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${command}" "to has been called" "${expected} times"
    return
  fi

  state::add_assertions_passed
}
