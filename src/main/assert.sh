#!/usr/bin/env bash

# The standalone 'bashunit assert' path: parsing, dispatch and exit-code handling.

function bashunit::main::is_assertion_function() {
  local name="$1"
  declare -F "assert_$name" &>/dev/null || declare -F "$name" &>/dev/null
}

# Check if assertion operates on exit codes
function bashunit::main::is_exit_code_assertion() {
  local name="$1"
  case "$name" in
  exit_code | successful_code | unsuccessful_code | general_error | command_not_found)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

function bashunit::main::cmd_assert() {
  case "${1:-}" in
  -h | --help)
    bashunit::console_header::print_assert_help
    exit 0
    ;;
  esac

  local first_arg="${1:-}"
  if [ -z "$first_arg" ]; then
    printf "%sError: Assert function name or command is required.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}"
    bashunit::console_header::print_assert_help
    exit 1
  fi

  # Disable strict mode for assert execution
  set +euo pipefail

  # Route to appropriate handler based on first argument
  if bashunit::main::is_assertion_function "$first_arg"; then
    # Old single-assertion syntax: bashunit assert <fn> <args...>
    local assert_fn="$first_arg"
    shift
    bashunit::main::exec_assert "$assert_fn" "$@"
  elif [ $# -ge 2 ] && bashunit::main::is_assertion_function "$2"; then
    # New multi-assertion syntax: bashunit assert "<cmd>" <assertion1> <arg1> ...
    # Detected by: first arg is not assertion, but second arg is an assertion name
    bashunit::main::exec_multi_assert "$@"
  else
    # Fallback: try as single assertion (may fail with function not found)
    bashunit::main::exec_assert "$@"
  fi
  exit $?
}

#############################
# Watch mode
#############################

function bashunit::main::exec_assert() {
  local original_assert_fn=$1
  local -a args=()
  local args_count=$(($# - 1))
  [ $# -gt 1 ] && args=("${@:2}")

  local assert_fn=$original_assert_fn

  if ! type "$assert_fn" >/dev/null 2>&1; then
    assert_fn="assert_$assert_fn"
    if ! type "$assert_fn" >/dev/null 2>&1; then
      echo "Function $original_assert_fn does not exist." 1>&2
      exit 127
    fi
  fi

  # Every assertion needs at least one argument. Without this guard args_count is
  # 0, so the last_index below is -1: Bash 3.x has no negative subscripts, so the
  # expansion failed with a raw `bad array subscript` and the run still exited 0
  # (#877).
  if [ "$args_count" -lt 1 ]; then
    printf "%sError: assert %s requires at least one argument.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "$original_assert_fn" "${_BASHUNIT_COLOR_DEFAULT}" >&2
    exit 1
  fi

  local last_index=$((args_count - 1))
  local last_arg="${args[$last_index]}"
  local output=""
  local inner_exit_code=0
  local bashunit_exit_code=0

  case "$assert_fn" in
  assert_exit_code)
    output=$(bashunit::main::handle_assert_exit_code "$last_arg")
    inner_exit_code=$?
    # Remove the last argument and append the exit code
    args=("${args[@]:0:last_index}")
    args[last_index]="$inner_exit_code"
    ;;
  *)
    # Every other assertion takes its argument as-is; no rewriting needed.
    ;;
  esac

  if [ -n "$output" ]; then
    echo "$output" 1>&1
    assert_fn="assert_same"
  fi

  bashunit::state::set_test_title "assert ${original_assert_fn#assert_}"

  "$assert_fn" "${args[@]}" 1>&2
  bashunit_exit_code=$?

  if [ "$(bashunit::state::get_tests_failed)" -gt 0 ] || [ "$(bashunit::state::get_assertions_failed)" -gt 0 ]; then
    return 1
  fi

  return "$bashunit_exit_code"
}

function bashunit::main::handle_assert_exit_code() {
  local cmd="$1"
  local output
  local inner_exit_code=0

  if command -v "${cmd%% *}" >/dev/null 2>&1; then
    output=$(eval "$cmd" 2>&1 || echo "inner_exit_code:$?")
    local last_line
    last_line=$(echo "$output" | tail -n 1)
    if [ "$(echo "$last_line" | "$GREP" -c 'inner_exit_code:[0-9]*' || true)" -gt 0 ]; then
      inner_exit_code=$(echo "$last_line" | grep -o 'inner_exit_code:[0-9]*' | cut -d':' -f2)
      local _re='^[0-9]+$'
      if [ "$(echo "$inner_exit_code" | "$GREP" -cE "$_re" || true)" -eq 0 ]; then
        inner_exit_code=1
      fi
      output=$(echo "$output" | sed '$d')
    fi
    echo "$output"
    return "$inner_exit_code"
  else
    echo "Command not found: $cmd" 1>&2
    return 127
  fi
}

# Execute multiple assertions on a single command output
# Usage: exec_multi_assert "command" assertion1 arg1 [assertion2 arg2 ...]
function bashunit::main::exec_multi_assert() {
  local cmd="$1"
  shift

  if [ $# -lt 1 ]; then
    printf "%sError: Multi-assertion mode requires at least one assertion.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
    printf "Usage: bashunit assert \"<command>\" <assertion1> <arg1> [<assertion2> <arg2>...]\n" 1>&2
    return 1
  fi

  if [ $# -lt 2 ] || [ $(($# % 2)) -ne 0 ]; then
    local assertion_name="${1:-}"
    printf "%sError: Missing argument for assertion '%s'.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "$assertion_name" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
    return 1
  fi

  local stdout
  local cmd_exit_code
  stdout=$(eval "$cmd" 2>&1)
  cmd_exit_code=$?

  if [ -n "$stdout" ]; then
    echo "$stdout" 1>&1
  fi

  local overall_result=0
  while [ $# -gt 0 ]; do
    local assertion_name="$1"
    local assertion_arg="${2:-}"

    if [ -z "$assertion_arg" ]; then
      printf "%sError: Missing argument for assertion '%s'.%s\n" \
        "${_BASHUNIT_COLOR_FAILED}" "$assertion_name" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
      return 1
    fi

    shift 2

    local assert_fn="$assertion_name"
    if ! type "$assert_fn" &>/dev/null; then
      assert_fn="assert_$assertion_name"
      if ! type "$assert_fn" &>/dev/null; then
        printf "%sError: Unknown assertion '%s'.%s\n" \
          "${_BASHUNIT_COLOR_FAILED}" "$assertion_name" "${_BASHUNIT_COLOR_DEFAULT}" 1>&2
        return 1
      fi
    fi

    bashunit::state::set_test_title "assert ${assertion_name#assert_}"

    if bashunit::main::is_exit_code_assertion "$assertion_name"; then
      # Exit code assertion: pass expected value and captured exit code
      "$assert_fn" "$assertion_arg" "" "$cmd_exit_code" 1>&2
    else
      # Output assertion: pass expected value and captured stdout
      "$assert_fn" "$assertion_arg" "$stdout" 1>&2
    fi

    if [ "$(bashunit::state::get_assertions_failed)" -gt 0 ]; then
      overall_result=1
    fi
  done

  return $overall_result
}
