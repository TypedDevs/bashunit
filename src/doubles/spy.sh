#!/usr/bin/env bash

# Spies: recording calls without changing behaviour, and the per-spy state slots.

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
  bashunit::helper::normalize_variable_name_to_slot "$command"
  variable=$_BASHUNIT_HELPER_VARNAME_OUT
  local file_var="_BASHUNIT_SPY_${variable}_TIMES_FILE"
  _BASHUNIT_SPY_TIMES_OUT=0
  _BASHUNIT_SPY_REGISTERED_OUT=false
  if [ -n "${!file_var-}" ]; then
    _BASHUNIT_SPY_REGISTERED_OUT=true
  fi
  if [ -f "${!file_var-}" ]; then
    # `read` is a builtin: the count is a single short line, so this avoids a
    # `cat` fork on a path a spy-heavy test hits once per assertion.
    local times_line=""
    read -r times_line <"${!file_var}" 2>/dev/null || times_line=""
    case "$times_line" in
    '' | *[!0-9]*) _BASHUNIT_SPY_TIMES_OUT=0 ;;
    *) _BASHUNIT_SPY_TIMES_OUT=$times_line ;;
    esac
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
  bashunit::helper::normalize_variable_name_to_slot "$command"
  variable=$_BASHUNIT_HELPER_VARNAME_OUT
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


##
# Records one call of a double: the raw and per-argument forms in the params
# file, and the incremented count in the times file. Shared by the spy and by
# a sequenced mock defined over one, so the two record identically.
# Arguments: $1 - params file, $2 - times file, $@ - the call's arguments
##
function bashunit::doubles::record_call() {
  local params_file=$1
  local times_file=$2
  shift 2

  local raw="$*"
  local serialized=""
  local arg
  for arg in "$@"; do
    serialized="$serialized$(builtin printf '%q' "$arg")"$'\x1f'
  done
  serialized=${serialized%$'\x1f'}
  builtin printf '%s\x1e%s\n' "$raw" "$serialized" >>"$params_file"

  local count=""
  read -r count <"$times_file" 2>/dev/null || count=""
  case "$count" in '' | *[!0-9]*) count=0 ;; esac
  builtin echo "$((count + 1))" >"$times_file"
}


function bashunit::spy() {
  local command=$1
  local exit_code_or_impl="${2:-}"
  local variable
  bashunit::helper::normalize_variable_name_to_slot "$command"
  variable=$_BASHUNIT_HELPER_VARNAME_OUT

  local times_file params_file
  local test_id="${BASHUNIT_CURRENT_TEST_ID:-global}"
  times_file=$(bashunit::temp_file "${test_id}_${variable}_times")
  params_file=$(bashunit::temp_file "${test_id}_${variable}_params")
  echo 0 >"$times_file"
  : >"$params_file"
  export "_BASHUNIT_SPY_${variable}_TIMES_FILE"="$times_file"
  export "_BASHUNIT_SPY_${variable}_PARAMS_FILE"="$params_file"

  # An all-digits second argument is an exit code; anything else non-empty is a
  # replacement implementation.
  local body_suffix=""
  if bashunit::doubles::is_exit_code "$exit_code_or_impl"; then
    body_suffix="return $exit_code_or_impl"
  elif [ -n "$exit_code_or_impl" ]; then
    body_suffix="$exit_code_or_impl \"\$@\""
  fi

  eval "function $command() {
    bashunit::doubles::record_call '$params_file' '$times_file' \"\$@\"
    $body_suffix
  }"

  export -f "${command?}"
  # The recorder travels with the double: an exported spy that reaches an
  # external script (bash 4+) would otherwise call a function the child has
  # never heard of.
  export -f bashunit::doubles::record_call

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}

