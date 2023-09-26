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

  eval "function $command() { export ${command}_params=(\"\$*\"); ((${command}_times++)); }"

  export -f "${command?}"
}

function assertHaveBeenCalledWith() {
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

  State::addAssertionsPassed
}

function assertHaveBeenCalled() {
  local command=$1
  local actual
  actual="${command}_times"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ${!actual} -eq 0 ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${command}" "has not been called at least" "once"
    return
  fi

  State::addAssertionsPassed
}

function assertHaveBeenCalledTimes() {
  local expected=$1
  local command=$2
  local actual
  actual="${command}_times"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ${!actual} -ne $expected ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${command}" "has not been called" "${expected} times"
    return
  fi

  State::addAssertionsPassed
}
