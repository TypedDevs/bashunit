#!/usr/bin/env bash

# Mocks: replacing a command's behaviour, and the registry the runner unwinds after each test.

declare -a _BASHUNIT_MOCKED_FUNCTIONS=()

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
      # Under --sandbox the command was a blocking shim before it was mocked;
      # dropping the mock must not hand the test the real thing.
      bashunit::sandbox::restore_shim "$command"
      local variable
      variable="$(bashunit::helper::normalize_variable_name "$command")"
      local times_file_var="_BASHUNIT_SPY_${variable}_TIMES_FILE"
      local params_file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
      local sequence_file_var="_BASHUNIT_MOCK_${variable}_SEQUENCE_FILE"
      [ -f "${!sequence_file_var-}" ] && rm -f "${!sequence_file_var}"
      unset "$sequence_file_var"
      [ -f "${!times_file_var-}" ] && rm -f "${!times_file_var}"
      [ -f "${!params_file_var-}" ] && rm -f "${!params_file_var}"
      unset "$times_file_var"
      unset "$params_file_var"
      break
    fi
  done
}


# True when $1 is an exit code rather than a replacement implementation, i.e. a
# non-empty all-digits string. Shared by both doubles so they read the same
# convention, and so the value interpolated into `return $1` is provably
# numeric — that is what keeps the generated body free of shell syntax.
function bashunit::doubles::is_exit_code() {
  case "$1" in
  '' | *[!0-9]*) return 1 ;;
  esac
  return 0
}


# Refuses a name the doubles cannot build a function from.
#
# All three doubles run `eval "function $command() { … }"`, so a name carrying
# whitespace or shell syntax is a syntax error and the user sees bashunit's
# internals rather than their mistake -- `mock "ls -l" echo hi` reported
# `syntax error near unexpected token '-l'` (#1136).
#
# Narrow on purpose: `foo-bar`, `a.b`, `x+y`, `a$b` and `a:b` are all legal
# function names in bash and legitimate commands to mock, so only the
# characters that actually break the eval are rejected.
function bashunit::doubles::refuse_unusable_name() {
  local fn=$1 command=$2

  case "$command" in
  '')
    bashunit::assert::fail_with "" "$fn" "expects a command name, got" "nothing"
    return 0
    ;;
  *[[:space:]\;\|\&\(\)\{\}\<\>\"\'\`]*)
    # Through fail_with, like an assertion: it labels the failure with the test
    # name and counts it, so the misuse is visible in a default run rather than
    # only under --strict.
    bashunit::assert::fail_with "" "$command" \
      "is not a usable command name for $fn; pass arguments after it, as in" "$fn ls -l"
    return 0
    ;;
  esac

  return 1
}


function bashunit::mock() {
  local command=$1
  shift

  if bashunit::doubles::refuse_unusable_name "mock" "$command"; then
    return 1
  fi

  if [ $# -eq 1 ] && bashunit::doubles::is_exit_code "$1"; then
    eval "function $command() { return $1; }"
  elif [ $# -gt 0 ]; then
    eval "function $command() { $* \"\$@\"; }"
  else
    eval "function $command() { builtin echo \"$($CAT)\" ; }"
  fi

  export -f "${command?}"

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}


##
# Replaces a command with a sequence of answers: each call consumes the next
# entry, and the last entry repeats once the sequence is exhausted (so a loop
# that runs one iteration more than the test planned keeps the final answer
# rather than falling off a cliff).
#
# Entries follow the same convention as bashunit::mock -- an all-digits entry
# is an exit code, anything else is a body -- which is also what keeps the
# generated `return N` free of anything but a number.
#
# Defining a sequence over an existing spy keeps the recording: the generated
# body calls the same recorder the spy's does.
# Arguments: $1 - command, $@ - the answers, in order
##
function bashunit::mock_sequence() {
  local command=$1
  shift

  if bashunit::doubles::refuse_unusable_name "mock_sequence" "$command"; then
    return 1
  fi

  if [ $# -eq 0 ]; then
    bashunit::assert::usage_error_detail "bashunit::mock_sequence" \
      "expects at least one answer after the command"
    return 2
  fi

  local variable
  bashunit::helper::normalize_variable_name_to_slot "$command"
  variable=$_BASHUNIT_HELPER_VARNAME_OUT

  local test_id="${BASHUNIT_CURRENT_TEST_ID:-global}"
  local step_file
  step_file=$(bashunit::temp_file "${test_id}_${variable}_sequence")
  builtin echo 1 >"$step_file"
  export "_BASHUNIT_MOCK_${variable}_SEQUENCE_FILE"="$step_file"

  local times_file_var="_BASHUNIT_SPY_${variable}_TIMES_FILE"
  local params_file_var="_BASHUNIT_SPY_${variable}_PARAMS_FILE"
  local record=""
  if [ -n "${!times_file_var-}" ]; then
    record="bashunit::doubles::record_call '${!params_file_var}' '${!times_file_var}' \"\$@\""
  fi

  local total=$#
  local index=0
  local arms=""
  local entry body
  for entry in "$@"; do
    index=$((index + 1))
    if bashunit::doubles::is_exit_code "$entry"; then
      body="return $entry"
    else
      body="$entry \"\$@\""
    fi
    # The last arm is the default one, which is what makes the final answer
    # repeat instead of the sequence running out.
    if [ "$index" -eq "$total" ]; then
      arms="$arms
    *) $body ;;"
    else
      arms="$arms
    $index) $body ;;"
    fi
  done

  eval "function $command() {
    $record
    local _step=1
    read -r _step < '$step_file' 2>/dev/null || _step=1
    case \"\$_step\" in '' | *[!0-9]*) _step=1 ;; esac
    if [ \"\$_step\" -lt $total ]; then
      builtin echo \"\$((_step + 1))\" > '$step_file'
    fi
    case \"\$_step\" in$arms
    esac
  }"

  export -f "${command?}"
  # The recorder travels with the double: an exported spy that reaches an
  # external script (bash 4+) would otherwise call a function the child has
  # never heard of.
  export -f bashunit::doubles::record_call

  _BASHUNIT_MOCKED_FUNCTIONS[${#_BASHUNIT_MOCKED_FUNCTIONS[@]}]="$command"
}
