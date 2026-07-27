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

_BASHUNIT_SPY_CALL_OUT=""
_BASHUNIT_SPY_CALL_TOTAL_OUT=0

# Reads the params file $1 in a single pass: the recorded line for call $2 (the
# last one when $2 is empty) lands in _BASHUNIT_SPY_CALL_OUT, the number of
# recorded calls in _BASHUNIT_SPY_CALL_TOTAL_OUT. Both are needed together,
# because the failure message names which call it compared.
# Arguments: $1 - params file, $2 - call index (optional)
function bashunit::spy::read_call_to_slots() {
  local file=$1
  local index=${2:-}
  _BASHUNIT_SPY_CALL_OUT=""
  _BASHUNIT_SPY_CALL_TOTAL_OUT=0

  if [ -z "$file" ] || [ ! -f "$file" ]; then
    return
  fi

  local current
  while IFS= read -r current; do
    _BASHUNIT_SPY_CALL_TOTAL_OUT=$((_BASHUNIT_SPY_CALL_TOTAL_OUT + 1))
    if [ -z "$index" ] || [ "$_BASHUNIT_SPY_CALL_TOTAL_OUT" = "$index" ]; then
      _BASHUNIT_SPY_CALL_OUT=$current
    fi
  done <"$file"
}

# Names the call a last-call/indexed assertion compared, for the failure block.
# Arguments: $1 - call index (empty for the last call), $2 - total calls
function bashunit::spy::compared_call() {
  if [ -n "$1" ]; then
    builtin echo "call $1 of $2"
  elif [ "$2" -eq 1 ]; then
    builtin echo "the only call"
  else
    builtin echo "the last of $2 calls"
  fi
}

_BASHUNIT_SPY_CALL_LOG_MAX=10
_BASHUNIT_SPY_CALL_LOG_OUT=""

# Renders the calls recorded for $1 into _BASHUNIT_SPY_CALL_LOG_OUT, one per
# line, capped at _BASHUNIT_SPY_CALL_LOG_MAX with an explicit "and N more".
# Empty when $1 is not a spy or was never called. Failure path only: reading the
# params file on every assertion would break the per-test fork budget.
# Arguments: $1 - command, $2 - "raw" (space-joined, default) or "args"
#            (per-argument, boundaries kept)
function bashunit::spy::call_log_to_slot() {
  local command=$1
  local field=${2:-raw}
  _BASHUNIT_SPY_CALL_LOG_OUT=""

  local variable
  variable="$(bashunit::helper::normalize_variable_name "$command")"
  local file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
  if [ -z "${!file_var-}" ] || [ ! -f "${!file_var}" ]; then
    return
  fi

  local entries=""
  local total=0
  local shown=0
  local line value
  while IFS= read -r line; do
    total=$((total + 1))
    if [ "$shown" -lt "$_BASHUNIT_SPY_CALL_LOG_MAX" ]; then
      if [ "$field" = args ]; then
        value=${line#*$'\x1e'}
        value=${value//$'\x1f'/ }
      else
        value=${line%%$'\x1e'*}
      fi
      entries="$entries
      ${_BASHUNIT_COLOR_FAINT}${total}:${_BASHUNIT_COLOR_DEFAULT} ${value}"
      shown=$((shown + 1))
    fi
  done <"${!file_var}"

  if [ "$total" -eq 0 ]; then
    return
  fi

  _BASHUNIT_SPY_CALL_LOG_OUT="\
    ${_BASHUNIT_COLOR_FAINT}Recorded calls to '${command}' (${total}):\
${_BASHUNIT_COLOR_DEFAULT}${entries}"

  local remaining=$((total - shown))
  if [ "$remaining" -gt 0 ]; then
    _BASHUNIT_SPY_CALL_LOG_OUT="$_BASHUNIT_SPY_CALL_LOG_OUT
      ${_BASHUNIT_COLOR_FAINT}… and ${remaining} more${_BASHUNIT_COLOR_DEFAULT}"
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
