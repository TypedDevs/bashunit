#!/usr/bin/env bash

declare -a MOCKED_FUNCTIONS=()

function unmock() {
  local command=$1

  for i in "${!MOCKED_FUNCTIONS[@]}"; do
    if [[ "${MOCKED_FUNCTIONS[$i]}" == "$command" ]]; then
      unset "MOCKED_FUNCTIONS[$i]"
      unset -f "$command"
      local variable
      variable="$(helper::normalize_variable_name "$command")"
      local times_file_var="${variable}_times_file"
      local params_file_var="${variable}_params_file"
      [[ -f "${!times_file_var-}" ]] && rm -f "${!times_file_var}"
      [[ -f "${!params_file_var-}" ]] && rm -f "${!params_file_var}"
      unset "${variable}_times"
      unset "${variable}_params"
      unset "$times_file_var"
      unset "$params_file_var"
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

  local times_file params_file
  times_file=$(temp_file "${variable}_times")
  params_file=$(temp_file "${variable}_params")
  echo 0 > "$times_file"
  : > "$params_file"
  export "${variable}_times_file"="$times_file"
  export "${variable}_params_file"="$params_file"

  eval "function $command() {
    ${variable}_params=(\"\$*\")
    echo \"\$*\" > '$params_file'
    ((${variable}_times++)) || true
    local _c=\$(cat '$times_file')
    _c=\$((_c+1))
    echo \"\$_c\" > '$times_file'
  }"

  export -f "${command?}"

  MOCKED_FUNCTIONS+=("$command")
}

function assert_have_been_called() {
  local command=$1
  local variable
  variable="$(helper::normalize_variable_name "$command")"
  local actual
  actual="${variable}_times"
  local file_var="${variable}_times_file"
  local times="${!actual-0}"
  if [[ -f "${!file_var-}" ]]; then
    times=$(cat "${!file_var}")
  fi
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $times -eq 0 ]]; then
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
  local file_var="${variable}_params_file"
  local params="${!actual-}"
  if [[ -f "${!file_var-}" ]]; then
    params=$(cat "${!file_var}")
  fi
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$params" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "but got " "$params"
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
  local file_var="${variable}_times_file"
  local times="${!actual-0}"
  if [[ -f "${!file_var-}" ]]; then
    times=$(cat "${!file_var}")
  fi
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ -z "${!actual-}" && $expected -ne 0 || $times -ne $expected ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${command}" "to has been called" "${expected} times"
    return
  fi

  state::add_assertions_passed
}
