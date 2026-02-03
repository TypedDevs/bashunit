#!/usr/bin/env bash

declare -a _BASHUNIT_MOCKED_FUNCTIONS=()

function bashunit::unmock() {
  local command=$1

  for i in "${!_BASHUNIT_MOCKED_FUNCTIONS[@]}"; do
    if [[ "${_BASHUNIT_MOCKED_FUNCTIONS[$i]}" == "$command" ]]; then
      unset "_BASHUNIT_MOCKED_FUNCTIONS[$i]"
      unset -f "$command"
      local variable
      variable="$(bashunit::helper::normalize_variable_name "$command")"
      local times_file_var="${variable}_times_file"
      local params_file_var="${variable}_params_file"
      [[ -f "${!times_file_var-}" ]] && rm -f "${!times_file_var}"
      [[ -f "${!params_file_var-}" ]] && rm -f "${!params_file_var}"
      unset "$times_file_var"
      unset "$params_file_var"
      break
    fi
  done
}

function bashunit::mock() {
  local command=$1
  shift

  if [[ $# -gt 0 ]]; then
    eval "function $command() { $* \"\$@\"; }"
  else
    eval "function $command() { echo \"$($CAT)\" ; }"
  fi

  export -f "${command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}

function bashunit::spy() {
  local command=$1
  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"

  local times_file params_file
  local test_id="${BASHUNIT_CURRENT_TEST_ID:-global}"
  times_file=$(bashunit::temp_file "${test_id}_${variable}_times")
  params_file=$(bashunit::temp_file "${test_id}_${variable}_params")
  echo 0 > "$times_file"
  : > "$params_file"
  export "${variable}_times_file"="$times_file"
  export "${variable}_params_file"="$params_file"

  eval "function $command() {
    local raw=\"\$*\"
    local serialized=\"\"
    local arg
    for arg in \"\$@\"; do
      serialized=\"\$serialized\$(printf '%q' \"\$arg\")$'\\x1f'\"
    done
    serialized=\${serialized%$'\\x1f'}
    printf '%s\x1e%s\\n' \"\$raw\" \"\$serialized\" >> '$params_file'
    local _c
    _c=\$(cat '$times_file' 2>/dev/null || echo 0)
    _c=\$((_c+1))
    echo \"\$_c\" > '$times_file'
  }"

  export -f "${command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}

function assert_have_been_called() {
  local command=$1
  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="${variable}_times_file"
  local times=0
  if [[ -f "${!file_var-}" ]]; then
    times=$(cat "${!file_var}" 2>/dev/null || echo 0)
  fi
  local label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $times -eq 0 ]]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "${label}" "${command}" "to have been called" "once"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_have_been_called_with() {
  local command=$1
  shift

  local index=""
  if [[ ${!#} =~ ^[0-9]+$ ]]; then
    index=${!#}
    set -- "${@:1:$#-1}"
  fi

  local expected="$*"

  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="${variable}_params_file"
  local line=""
  if [[ -f "${!file_var-}" ]]; then
    if [[ -n $index ]]; then
      line=$(sed -n "${index}p" "${!file_var}" 2>/dev/null || true)
    else
      line=$(tail -n 1 "${!file_var}" 2>/dev/null || true)
    fi
  fi

  local raw
  IFS=$'\x1e' read -r raw _ <<<"$line" || true

  if [[ "$expected" != "$raw" ]]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "$(bashunit::helper::normalize_test_function_name \
      "${FUNCNAME[1]}")" "$expected" "but got " "$raw"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_have_been_called_times() {
  local expected_count=$1
  local command=$2
  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="${variable}_times_file"
  local times=0
  if [[ -f "${!file_var-}" ]]; then
    times=$(cat "${!file_var}" 2>/dev/null || echo 0)
  fi
  local label="${3:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  if [[ $times -ne $expected_count ]]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "${label}" "${command}" \
      "to have been called" "${expected_count} times" \
      "actual" "${times} times"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_called() {
  local command=$1
  local label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  assert_have_been_called_times 0 "$command" "$label"
}
