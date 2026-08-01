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


function bashunit::mock() {
  local command=$1
  shift

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

