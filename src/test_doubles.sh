#!/usr/bin/env bash

declare -a _BASHUNIT_MOCKED_FUNCTIONS=()

function bashunit::unmock() {
  local __bu_command=$1

  if [ "${#_BASHUNIT_MOCKED_FUNCTIONS[@]}" -eq 0 ]; then
    return
  fi

  local __bu_i
  for __bu_i in "${!_BASHUNIT_MOCKED_FUNCTIONS[@]}"; do
    if [ "${_BASHUNIT_MOCKED_FUNCTIONS[$__bu_i]:-}" = "$__bu_command" ]; then
      unset "_BASHUNIT_MOCKED_FUNCTIONS[$__bu_i]"
      unset -f "$__bu_command"
      local __bu_variable
      __bu_variable="$(bashunit::helper::normalize_variable_name "$__bu_command")"
      local __bu_times_file_var="${__bu_variable}_times_file"
      local __bu_params_file_var="${__bu_variable}_params_file"
      [ -f "${!__bu_times_file_var-}" ] && rm -f "${!__bu_times_file_var}"
      [ -f "${!__bu_params_file_var-}" ] && rm -f "${!__bu_params_file_var}"
      unset "$__bu_times_file_var"
      unset "$__bu_params_file_var"
      break
    fi
  done
}

function bashunit::mock() {
  local __bu_command=$1
  shift

  if [ $# -gt 0 ]; then
    eval "function $__bu_command() { $* \"\$@\"; }"
  else
    eval "function $__bu_command() { builtin echo \"$($CAT)\" ; }"
  fi

  export -f "${__bu_command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$__bu_command"
}

function bashunit::spy() {
  local __bu_command=$1
  local __bu_exit_code_or_impl="${2:-}"
  local __bu_variable
  __bu_variable="$(bashunit::helper::normalize_variable_name "$__bu_command")"

  local __bu_times_file __bu_params_file
  local __bu_test_id="${BASHUNIT_CURRENT_TEST_ID:-global}"
  __bu_times_file=$(bashunit::temp_file "${__bu_test_id}_${__bu_variable}_times")
  __bu_params_file=$(bashunit::temp_file "${__bu_test_id}_${__bu_variable}_params")
  echo 0 >"$__bu_times_file"
  : >"$__bu_params_file"
  export "${__bu_variable}_times_file"="$__bu_times_file"
  export "${__bu_variable}_params_file"="$__bu_params_file"

  local __bu_body_suffix=""
  if [[ "$__bu_exit_code_or_impl" =~ ^[0-9]+$ ]]; then
    __bu_body_suffix="return $__bu_exit_code_or_impl"
  elif [ -n "$__bu_exit_code_or_impl" ]; then
    __bu_body_suffix="$__bu_exit_code_or_impl \"\$@\""
  fi

  eval "function $__bu_command() {
    local raw=\"\$*\"
    local serialized=\"\"
    local arg
    for arg in \"\$@\"; do
      serialized=\"\$serialized\$(builtin printf '%q' \"\$arg\")$'\\x1f'\"
    done
    serialized=\${serialized%$'\\x1f'}
    builtin printf '%s\x1e%s\\n' \"\$raw\" \"\$serialized\" >> '$__bu_params_file'
    local _c
    _c=\$(cat '$__bu_times_file' 2>/dev/null || builtin echo 0)
    _c=\$((_c+1))
    builtin echo \"\$_c\" > '$__bu_times_file'
    $__bu_body_suffix
  }"

  export -f "${__bu_command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$__bu_command"
}

function assert_have_been_called() {
  local __bu_command=$1
  local __bu_variable
  __bu_variable="$(bashunit::helper::normalize_variable_name "$__bu_command")"
  local __bu_file_var="${__bu_variable}_times_file"
  local __bu_times=0
  if [ -f "${!__bu_file_var-}" ]; then
    __bu_times=$(cat "${!__bu_file_var}" 2>/dev/null || builtin echo 0)
  fi
  local __bu_label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [ "$__bu_times" -eq 0 ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "${__bu_label}" "${__bu_command}" "to have been called" "once"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_have_been_called_with() {
  local __bu_command=$1
  shift

  local __bu_index=""
  if [ "$(echo "${!#}" | "$GREP" -cE '^[0-9]+$' || true)" -gt 0 ]; then
    __bu_index=${!#}
    set -- "${@:1:$#-1}"
  fi

  local __bu_expected="$*"

  local __bu_variable
  __bu_variable="$(bashunit::helper::normalize_variable_name "$__bu_command")"
  local __bu_file_var="${__bu_variable}_params_file"
  local __bu_line=""
  if [ -f "${!__bu_file_var-}" ]; then
    if [ -n "$__bu_index" ]; then
      __bu_line=$(sed -n "${__bu_index}p" "${!__bu_file_var}" 2>/dev/null || true)
    else
      __bu_line=$(tail -n 1 "${!__bu_file_var}" 2>/dev/null || true)
    fi
  fi

  local __bu_raw
  IFS=$'\x1e' read -r __bu_raw _ <<<"$__bu_line" || true

  if [ "$__bu_expected" != "$__bu_raw" ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "$(bashunit::helper::normalize_test_function_name \
      "${FUNCNAME[1]}")" "$__bu_expected" "but got " "$__bu_raw"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_have_been_called_times() {
  local __bu_expected_count=$1
  local __bu_command=$2
  local __bu_variable
  __bu_variable="$(bashunit::helper::normalize_variable_name "$__bu_command")"
  local __bu_file_var="${__bu_variable}_times_file"
  local __bu_times=0
  if [ -f "${!__bu_file_var-}" ]; then
    __bu_times=$(cat "${!__bu_file_var}" 2>/dev/null || builtin echo 0)
  fi
  local __bu_label="${3:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  if [ "$__bu_times" -ne "$__bu_expected_count" ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "${__bu_label}" "${__bu_command}" \
      "to have been called" "${__bu_expected_count} times" \
      "actual" "${__bu_times} times"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_have_been_called_nth_with() {
  local __bu_nth=$1
  local __bu_command=$2
  shift 2
  local __bu_expected="$*"

  local __bu_variable
  __bu_variable="$(bashunit::helper::normalize_variable_name "$__bu_command")"
  local __bu_times_file_var="${__bu_variable}_times_file"
  local __bu_file_var="${__bu_variable}_params_file"
  local __bu_label
  __bu_label="$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")"

  local __bu_times=0
  if [ -f "${!__bu_times_file_var-}" ]; then
    __bu_times=$(cat "${!__bu_times_file_var}" 2>/dev/null || builtin echo 0)
  fi

  if [ "$__bu_nth" -gt "$__bu_times" ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "${__bu_label}" \
      "expected call" "at index ${__bu_nth} but" "only called ${__bu_times} times"
    return
  fi

  local __bu_line=""
  if [ -f "${!__bu_file_var-}" ]; then
    __bu_line=$(sed -n "${__bu_nth}p" "${!__bu_file_var}" 2>/dev/null || true)
  fi

  local __bu_raw
  IFS=$'\x1e' read -r __bu_raw _ <<<"$__bu_line" || true

  if [ "$__bu_expected" != "$__bu_raw" ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "${__bu_label}" \
      "$__bu_expected" "but got " "$__bu_raw"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_called() {
  local __bu_command=$1
  local __bu_label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  assert_have_been_called_times 0 "$__bu_command" "$__bu_label"
}
