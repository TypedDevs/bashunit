#!/usr/bin/env bash

declare -a _BASHUNIT_MOCKED_FUNCTIONS=()

# Spy/mock state is keyed by the sanitized command name and stored in globals
# prefixed with `_BASHUNIT_SPY_` so they cannot collide with caller locals.
# A test that does `local foo_times_file=...` is harmless because the helper
# resolves `_BASHUNIT_SPY_foo_TIMES_FILE` instead.

_BASHUNIT_SPY_TIMES_OUT=0
_BASHUNIT_SPY_REGISTERED_OUT=false

# Reads the recorded call count for $1 into _BASHUNIT_SPY_TIMES_OUT (0 when
# never called) and whether $1 is a live spy into _BASHUNIT_SPY_REGISTERED_OUT.
# Shared by the call-count assertions instead of each repeating the "resolve
# times file, cat it, default to 0" sequence.
function bashunit::spy::times_to_slot() {
  local command="$1"
  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="_BASHUNIT_SPY_${variable}_TIMES_FILE"
  _BASHUNIT_SPY_TIMES_OUT=0
  _BASHUNIT_SPY_REGISTERED_OUT=false
  if [ -n "${!file_var-}" ]; then
    _BASHUNIT_SPY_REGISTERED_OUT=true
  fi
  if [ -f "${!file_var-}" ]; then
    _BASHUNIT_SPY_TIMES_OUT=$(cat "${!file_var}" 2>/dev/null || builtin echo 0)
  fi
}

# Fails the calling assertion because $1 is not a registered spy. Reporting
# "never called" for a name that was never spied — a typo, or a spy that was
# unmocked — makes the assertion vacuous while still printing green.
# Arguments: $1 - command, $2 - test label
function bashunit::spy::fail_unregistered() {
  bashunit::state::add_assertions_failed
  bashunit::console_results::print_failed_test "$2" "$1" \
    "was never registered as a spy; call it first with" "bashunit::spy $1"
}

_BASHUNIT_SPY_SERIALIZED_OUT=""

# Serializes the given arguments into _BASHUNIT_SPY_SERIALIZED_OUT exactly the
# way bashunit::spy records a call: each argument through `printf '%q'`, joined
# with \x1f. Unlike the space-joined `raw` field, this keeps the argument
# boundaries, so `f "a b"` and `f a b` serialize differently.
function bashunit::spy::serialize_args_to_slot() {
  local serialized=""
  local arg
  for arg in "$@"; do
    serialized="$serialized$(builtin printf '%q' "$arg")"$'\x1f'
  done
  _BASHUNIT_SPY_SERIALIZED_OUT=${serialized%$'\x1f'}
}

function bashunit::unmock() {
  local command=$1

  if [ "${#_BASHUNIT_MOCKED_FUNCTIONS[@]}" -eq 0 ]; then
    return
  fi

  local i
  for i in "${!_BASHUNIT_MOCKED_FUNCTIONS[@]}"; do
    if [ "${_BASHUNIT_MOCKED_FUNCTIONS[$i]:-}" = "$command" ]; then
      unset "_BASHUNIT_MOCKED_FUNCTIONS[$i]"
      unset -f "$command"
      local variable
      variable="$(bashunit::helper::normalize_variable_name "$command")"
      local times_file_var="_BASHUNIT_SPY_${variable}_TIMES_FILE"
      local params_file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
      [ -f "${!times_file_var-}" ] && rm -f "${!times_file_var}"
      [ -f "${!params_file_var-}" ] && rm -f "${!params_file_var}"
      unset "$times_file_var"
      unset "$params_file_var"
      break
    fi
  done
}

function bashunit::mock() {
  local command=$1
  shift

  if [ $# -gt 0 ]; then
    eval "function $command() { $* \"\$@\"; }"
  else
    eval "function $command() { builtin echo \"$($CAT)\" ; }"
  fi

  export -f "${command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}

function bashunit::spy() {
  local command=$1
  local exit_code_or_impl="${2:-}"
  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"

  local times_file params_file
  local test_id="${BASHUNIT_CURRENT_TEST_ID:-global}"
  times_file=$(bashunit::temp_file "${test_id}_${variable}_times")
  params_file=$(bashunit::temp_file "${test_id}_${variable}_params")
  echo 0 >"$times_file"
  : >"$params_file"
  export "_BASHUNIT_SPY_${variable}_TIMES_FILE"="$times_file"
  export "_BASHUNIT_SPY_${variable}_PARAMS_FILE"="$params_file"

  # An all-digits second argument is an exit code; anything else non-empty is a
  # replacement implementation. The `case` glob is the Bash 3.0 form of the old
  # `[[ =~ ^[0-9]+$ ]]` (identical domain: a value is all-digits iff it is
  # non-empty and contains no non-digit) and it keeps the interpolation below
  # provably numeric, so `return $exit_code_or_impl` cannot inject shell syntax.
  local body_suffix=""
  local _is_exit_code=false
  case "$exit_code_or_impl" in
  '' | *[!0-9]*) ;;
  *) _is_exit_code=true ;;
  esac
  if [ "$_is_exit_code" = true ]; then
    body_suffix="return $exit_code_or_impl"
  elif [ -n "$exit_code_or_impl" ]; then
    body_suffix="$exit_code_or_impl \"\$@\""
  fi

  eval "function $command() {
    local raw=\"\$*\"
    local serialized=\"\"
    local arg
    for arg in \"\$@\"; do
      serialized=\"\$serialized\$(builtin printf '%q' \"\$arg\")\"$'\\x1f'
    done
    serialized=\${serialized%$'\\x1f'}
    builtin printf '%s\x1e%s\\n' \"\$raw\" \"\$serialized\" >> '$params_file'
    local _c
    _c=\$(cat '$times_file' 2>/dev/null || builtin echo 0)
    _c=\$((_c+1))
    builtin echo \"\$_c\" > '$times_file'
    $body_suffix
  }"

  export -f "${command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}

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
    bashunit::console_results::print_failed_test "${label}" "${command}" "to have been called" "once"
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

  local line=""
  if [ -f "${!file_var-}" ]; then
    if [ -n "$index" ]; then
      line=$(sed -n "${index}p" "${!file_var}" 2>/dev/null || true)
    else
      line=$(tail -n 1 "${!file_var}" 2>/dev/null || true)
    fi
  fi

  local raw
  IFS=$'\x1e' read -r raw _ <<<"$line" || true

  if [ "$expected" != "$raw" ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "$label" "$expected" "but got " "$raw"
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

  local line=""
  if [ -f "${!file_var-}" ]; then
    line=$(tail -n 1 "${!file_var}" 2>/dev/null || true)
  fi

  local actual
  IFS=$'\x1e' read -r _ actual <<<"$line" || true

  if [ "$expected" != "$actual" ]; then
    bashunit::state::add_assertions_failed
    bashunit::console_results::print_failed_test "$label" \
      "${expected//$'\x1f'/ }" "but got " "${actual//$'\x1f'/ }"
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
    bashunit::console_results::print_failed_test "${label}" "${command}" \
      "to have been called" "${expected_count} times" \
      "actual" "${times} times"
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
    bashunit::console_results::print_failed_test "${label}" \
      "expected call" "at index ${nth} but" "only called ${times} times"
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
    bashunit::console_results::print_failed_test "${label}" \
      "$expected" "but got " "$raw"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_called() {
  local command=$1
  local label="${2:-$(bashunit::helper::normalize_test_function_name "${FUNCNAME[1]}")}"
  assert_have_been_called_times 0 "$command" "$label"
}
