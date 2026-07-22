#!/usr/bin/env bash

# Helper to mark assertion as failed and set the guard flag
function bashunit::assert::mark_failed() {
  bashunit::state::add_assertions_failed
  bashunit::state::mark_assertion_failed_in_test
}

# Guard clause to skip assertion if one already failed in test (when stop-on-assertion is enabled)
function bashunit::assert::should_skip() {
  bashunit::env::is_stop_on_assertion_failure_enabled && ((_BASHUNIT_ASSERTION_FAILED_IN_TEST))
}

_BASHUNIT_ASSERT_LABEL_OUT=""

# Resolve assertion label into the slot _BASHUNIT_ASSERT_LABEL_OUT with no fork:
# use custom label if provided, otherwise derive from the test function name.
# Must be called at the same stack depth as the echoing wrapper so the test-frame
# fallback keeps resolving against the caller of the assertion.
function bashunit::assert::label_to_slot() {
  local custom_label="${1:-}"
  if [ -n "$custom_label" ]; then
    _BASHUNIT_ASSERT_LABEL_OUT=$custom_label
    return
  fi
  bashunit::helper::find_test_function_name_to_slot
  bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
  _BASHUNIT_ASSERT_LABEL_OUT=$_BASHUNIT_HELPER_NORMALIZED_OUT
}

_BASHUNIT_ASSERT_JOINED_OUT=""

# Join positional args into _BASHUNIT_ASSERT_JOINED_OUT with no fork.
# Mirrors $(printf '%s\n' "$@"): joins with newlines and strips trailing
# newlines, so callers that match on the result behave exactly as the previous
# command-substitution did.
function bashunit::assert::join_to_slot() {
  local IFS=$'\n'
  local joined="$*"
  while [ "$joined" != "${joined%$'\n'}" ]; do
    joined="${joined%$'\n'}"
  done
  _BASHUNIT_ASSERT_JOINED_OUT=$joined
}

# Resolve assertion label: use custom label if provided, otherwise derive from test function name
function bashunit::assert::label() {
  bashunit::assert::label_to_slot "${1:-}"
  builtin echo "$_BASHUNIT_ASSERT_LABEL_OUT"
}

function bashunit::fail() {
  bashunit::assert::should_skip && return 0

  local message="${1:-${FUNCNAME[1]}}"

  bashunit::helper::find_test_function_name_to_slot
  bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
  local label=$_BASHUNIT_HELPER_NORMALIZED_OUT
  bashunit::assert::mark_failed
  bashunit::console_results::print_failure_message "${label}" "$message"
}

function assert_true() {
  bashunit::assert::should_skip && return 0

  local actual="$1"

  # Check for expected literal values first
  case "$actual" in
  "")
    bashunit::handle_bool_assertion_failure "true or 0" "$actual"
    return
    ;;
  "true" | "0")
    bashunit::state::add_assertions_passed
    return
    ;;
  "false" | "1")
    bashunit::handle_bool_assertion_failure "true or 0" "$actual"
    return
    ;;
  esac

  # Run command or eval and check the exit code
  bashunit::run_command_or_eval "$actual"
  local exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    bashunit::handle_bool_assertion_failure "command or function with zero exit code" "exit code: $exit_code"
  else
    bashunit::state::add_assertions_passed
  fi
}

function assert_false() {
  bashunit::assert::should_skip && return 0

  local actual="$1"

  # Check for expected literal values first
  case "$actual" in
  "")
    bashunit::handle_bool_assertion_failure "false or 1" "$actual"
    return
    ;;
  "false" | "1")
    bashunit::state::add_assertions_passed
    return
    ;;
  "true" | "0")
    bashunit::handle_bool_assertion_failure "false or 1" "$actual"
    return
    ;;
  esac

  # Run command or eval and check the exit code
  bashunit::run_command_or_eval "$actual"
  local exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    bashunit::handle_bool_assertion_failure "command or function with non-zero exit code" "exit code: $exit_code"
  else
    bashunit::state::add_assertions_passed
  fi
}

function bashunit::run_command_or_eval() {
  local cmd="$1"

  case "$cmd" in
  eval\ * | eval)
    eval "${cmd#eval }" &>/dev/null
    ;;
  *[=[:space:]]* | "")
    # An alias name never contains "=" or whitespace, so this can't be an alias
    # invocation: run it directly. Guarding here also stops `alias -- "$cmd"`
    # below from *defining* an alias as a side effect when "$cmd" looks like
    # "name=value" (which would wrongly succeed).
    "$cmd" &>/dev/null
    ;;
  *)
    # Detect aliases with the `alias` builtin instead of forking
    # `command -v | grep`: it exits 0 only for a defined alias, matching the
    # old `^alias` check for functions/binaries/unknown commands (all non-zero).
    if alias -- "$cmd" >/dev/null 2>&1; then
      eval "$cmd" &>/dev/null
    else
      "$cmd" &>/dev/null
    fi
    ;;
  esac
  return $?
}

function bashunit::handle_bool_assertion_failure() {
  local expected="$1"
  local got="$2"
  bashunit::helper::find_test_function_name_to_slot
  bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
  local label=$_BASHUNIT_HELPER_NORMALIZED_OUT

  bashunit::assert::mark_failed
  bashunit::console_results::print_failed_test "$label" "$expected" "but got " "$got"
}

function assert_same() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if [ "$expected" != "$actual" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  bashunit::str::strip_ansi_to_slot "$actual"
  local actual_cleaned=$_BASHUNIT_STR_STRIPPED_OUT
  bashunit::str::strip_ansi_to_slot "$expected"
  local expected_cleaned=$_BASHUNIT_STR_STRIPPED_OUT

  if [ "$expected_cleaned" != "$actual_cleaned" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected_cleaned}" "but got " "${actual_cleaned}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  bashunit::str::strip_ansi_to_slot "$actual"
  local actual_cleaned=$_BASHUNIT_STR_STRIPPED_OUT
  bashunit::str::strip_ansi_to_slot "$expected"
  local expected_cleaned=$_BASHUNIT_STR_STRIPPED_OUT

  if [ "$expected_cleaned" = "$actual_cleaned" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected_cleaned}" "to not be" "${actual_cleaned}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local label_override="${2:-}"

  if [ "$expected" != "" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "to be empty" "but got " "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local label_override="${2:-}"

  if [ "$expected" = "" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "to not be empty" "but got " "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_same() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if [ "$expected" = "$actual" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to not be" "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_contains() {
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local label_override=""
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected"*) ;;
  *)
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_contains_ignore_case() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  # Bash 3.0 compatible: use tr for case-insensitive comparison
  # (shopt nocasematch was introduced in Bash 3.1)
  local expected_lower
  local actual_lower
  expected_lower=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
  actual_lower=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')

  case "$actual_lower" in
  *"$expected_lower"*) ;;
  *)
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_not_contains() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected"*)
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_matches() {
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$expected" || true)" -eq 0 ]; then
    # Retry with newlines collapsed for cross-line patterns
    if [ "$(printf '%s' "$actual" | tr '\n' ' ' | "$GREP" -cE "$expected" || true)" -eq 0 ]; then
      bashunit::helper::find_test_function_name_to_slot
      bashunit::helper::normalize_test_function_name_to_slot "$_BASHUNIT_HELPER_TESTFN_OUT"
      local label=$_BASHUNIT_HELPER_NORMALIZED_OUT
      bashunit::assert::mark_failed
      bashunit::console_results::print_failed_test "${label}" "${actual}" "to match" "${expected}"
      return
    fi
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_matches() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  # Check both line-by-line and with newlines collapsed for cross-line patterns
  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$expected" || true)" -gt 0 ] ||
    [ "$(printf '%s' "$actual" | tr '\n' ' ' | "$GREP" -cE "$expected" || true)" -gt 0 ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_exec() {
  bashunit::assert::should_skip && return 0
  local label_override=""

  local cmd="$1"
  shift

  local expected_exit=0
  local expected_stdout=""
  local expected_stderr=""
  local stdout_needle=""
  local stdout_no_needle=""
  local stderr_needle=""
  local stderr_no_needle=""
  local stdin_input=""
  local check_stdout=false
  local check_stderr=false
  local check_stdout_contains=false
  local check_stdout_not_contains=false
  local check_stderr_contains=false
  local check_stderr_not_contains=false
  local check_stdin=false

  while [ $# -gt 0 ]; do
    case "$1" in
    --exit)
      expected_exit="$2"
      shift 2
      ;;
    --stdout)
      expected_stdout="$2"
      check_stdout=true
      shift 2
      ;;
    --stderr)
      expected_stderr="$2"
      check_stderr=true
      shift 2
      ;;
    --stdout-contains)
      stdout_needle="$2"
      check_stdout_contains=true
      shift 2
      ;;
    --stdout-not-contains)
      stdout_no_needle="$2"
      check_stdout_not_contains=true
      shift 2
      ;;
    --stderr-contains)
      stderr_needle="$2"
      check_stderr_contains=true
      shift 2
      ;;
    --stderr-not-contains)
      stderr_no_needle="$2"
      check_stderr_not_contains=true
      shift 2
      ;;
    --stdin)
      stdin_input="$2"
      check_stdin=true
      shift 2
      ;;
    *)
      shift
      ;;
    esac
  done

  local stdout_file stderr_file
  stdout_file=$("$MKTEMP")
  stderr_file=$("$MKTEMP")

  if $check_stdin; then
    local stdin_file
    stdin_file=$("$MKTEMP")
    printf '%s' "$stdin_input" >"$stdin_file"
    eval "$cmd" <"$stdin_file" >"$stdout_file" 2>"$stderr_file"
    local exit_code=$?
    rm -f "$stdin_file"
  else
    eval "$cmd" >"$stdout_file" 2>"$stderr_file"
    local exit_code=$?
  fi

  local stdout
  stdout=$(cat "$stdout_file")
  local stderr
  stderr=$(cat "$stderr_file")

  rm -f "$stdout_file" "$stderr_file"

  local expected_desc="exit: $expected_exit"
  local actual_desc="exit: $exit_code"
  local failed=0

  if [ "$exit_code" -ne "$expected_exit" ]; then
    failed=1
  fi

  if $check_stdout; then
    expected_desc="$expected_desc"$'\n'"stdout: $expected_stdout"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    if [ "$stdout" != "$expected_stdout" ]; then
      failed=1
    fi
  fi

  if $check_stdout_contains; then
    expected_desc="$expected_desc"$'\n'"stdout contains: $stdout_needle"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    case "$stdout" in
    *"$stdout_needle"*) ;;
    *) failed=1 ;;
    esac
  fi

  if $check_stdout_not_contains; then
    expected_desc="$expected_desc"$'\n'"stdout not contains: $stdout_no_needle"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    case "$stdout" in
    *"$stdout_no_needle"*) failed=1 ;;
    esac
  fi

  if $check_stderr; then
    expected_desc="$expected_desc"$'\n'"stderr: $expected_stderr"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    if [ "$stderr" != "$expected_stderr" ]; then
      failed=1
    fi
  fi

  if $check_stderr_contains; then
    expected_desc="$expected_desc"$'\n'"stderr contains: $stderr_needle"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    case "$stderr" in
    *"$stderr_needle"*) ;;
    *) failed=1 ;;
    esac
  fi

  if $check_stderr_not_contains; then
    expected_desc="$expected_desc"$'\n'"stderr not contains: $stderr_no_needle"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    case "$stderr" in
    *"$stderr_no_needle"*) failed=1 ;;
    esac
  fi

  if [ "$failed" -eq 1 ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "$label" "$expected_desc" "but got " "$actual_desc"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_exit_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code="$1"

  if [ "$actual_exit_code" -ne "$expected_exit_code" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_successful_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code=0

  if [ "$actual_exit_code" -ne "$expected_exit_code" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_unsuccessful_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  if [ "$actual_exit_code" -eq 0 ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual_exit_code}" "to be non-zero" "but was 0"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_general_error() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code=1

  if [ "$actual_exit_code" -ne "$expected_exit_code" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_command_not_found() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  local label_override=""
  bashunit::assert::should_skip && return 0

  local expected_exit_code=127

  if [ "$actual_exit_code" -ne "$expected_exit_code" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_starts_with() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  "$expected"*) ;;
  *)
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to start with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_string_not_starts_with() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  case "$actual" in
  "$expected"*)
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not start with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_string_ends_with() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected") ;;
  *)
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to end with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_string_not_ends_with() {
  local label_override=""
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  bashunit::assert::join_to_slot "${actual_arr[@]}"
  local actual=$_BASHUNIT_ASSERT_JOINED_OUT

  case "$actual" in
  *"$expected")
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not end with" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_less_than() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -lt "$expected" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be less than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_less_or_equal_than() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -le "$expected" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be less or equal than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_greater_than() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -gt "$expected" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be greater than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_greater_or_equal_than() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local label_override="${3:-}"

  if ! [ "$actual" -ge "$expected" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be greater or equal than" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

##
# Whether a value looks like a number (integer or decimal, optional sign).
# Returns: 0 when numeric, 1 otherwise.
##
function bashunit::assert::_is_numeric() {
  local value="$1"
  case "$value" in
  '' | *[!0-9.+-]*) return 1 ;;
  esac
  # Must contain at least one digit (rejects ".", "-", "+").
  case "$value" in
  *[0-9]*) return 0 ;;
  esac
  return 1
}

##
# Asserts the actual value is within +/- delta of the expected value:
# |actual - expected| <= delta. Supports floats via bashunit::math::calculate.
# Arguments: $1 - expected, $2 - actual, $3 - delta
##
function assert_within_delta() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local delta="$3"

  if ! bashunit::assert::_is_numeric "$expected" ||
    ! bashunit::assert::_is_numeric "$actual" ||
    ! bashunit::assert::_is_numeric "$delta"; then
    bashunit::assert::label_to_slot
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${_BASHUNIT_ASSERT_LABEL_OUT}" "${expected} ${actual} ${delta}" \
      "to all be numeric" "but got a non-numeric value"
    return
  fi

  local diff
  diff="$(bashunit::math::calculate "$expected - $actual")"
  case "$diff" in
  -*) diff="${diff#-}" ;;
  esac

  if [ "$(bashunit::math::calculate "$diff <= $delta")" != "1" ]; then
    bashunit::assert::label_to_slot
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${_BASHUNIT_ASSERT_LABEL_OUT}" "${actual}" "to be within ${delta} of" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_line_count() {
  bashunit::assert::should_skip && return 0
  local IFS=$' \t\n'

  local expected="$1"
  local -a input_arr
  input_arr=("${@:2}")
  local label_override=""
  local input_str
  input_str=$(printf '%s\n' ${input_arr+"${input_arr[@]}"})

  if [ -z "$input_str" ]; then
    local actual=0
  else
    # Count lines without forking: one line plus each real newline, plus each
    # literal "\n" (backslash-n) escape, which counts as an extra line break.
    local actual=1
    local _rest="$input_str"
    while [ "$_rest" != "${_rest#*$'\n'}" ]; do
      _rest="${_rest#*$'\n'}"
      actual=$((actual + 1))
    done
    _rest="$input_str"
    while [ "$_rest" != "${_rest#*\\n}" ]; do
      _rest="${_rest#*\\n}"
      actual=$((actual + 1))
    done
  fi

  if [ "$expected" != "$actual" ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT

    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${input_str}" \
      "to contain number of lines equal to" "${expected}" \
      "but found" "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function bashunit::format_to_regex() {
  local format="$1"
  local regex=""
  local i=0
  local len=${#format}

  while [ $i -lt "$len" ]; do
    local char="${format:$i:1}"
    if [ "$char" = "%" ] && [ $((i + 1)) -lt "$len" ]; then
      local next="${format:$((i + 1)):1}"
      case "$next" in
      d) regex="${regex}[0-9]+" ;;
      i) regex="${regex}[+-]?[0-9]+" ;;
      f) regex="${regex}[+-]?[0-9]*\\.?[0-9]+" ;;
      s) regex="${regex}[^ ]+" ;;
      x) regex="${regex}[0-9a-fA-F]+" ;;
      e) regex="${regex}[+-]?[0-9]*\\.?[0-9]+[eE][+-]?[0-9]+" ;;
      %) regex="${regex}%" ;;
      *)
        regex="${regex}%${next}"
        ;;
      esac
      i=$((i + 2))
    else
      case "$char" in
      . | '*' | '+' | '?' | '(' | ')' | '[' | ']' | '{' | '}' | '|' | '^' | '$')
        regex="${regex}\\${char}"
        ;;
      \\)
        regex="${regex}\\\\"
        ;;
      *)
        regex="${regex}${char}"
        ;;
      esac
      i=$((i + 1))
    fi
  done

  printf '%s' "^${regex}$"
}

function assert_string_matches_format() {
  bashunit::assert::should_skip && return 0

  local format="$1"
  local actual="$2"
  local label_override="${3:-}"

  local regex
  regex="$(bashunit::format_to_regex "$format")"

  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$regex" || true)" -eq 0 ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to match format" "${format}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_not_matches_format() {
  bashunit::assert::should_skip && return 0

  local format="$1"
  local actual="$2"
  local label_override="${3:-}"

  local regex
  regex="$(bashunit::format_to_regex "$format")"

  if [ "$(printf '%s' "$actual" | "$GREP" -cE "$regex" || true)" -gt 0 ]; then
    bashunit::assert::label_to_slot "${label_override:-}"
    local label=$_BASHUNIT_ASSERT_LABEL_OUT
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not match format" "${format}"
    return
  fi

  bashunit::state::add_assertions_passed
}
