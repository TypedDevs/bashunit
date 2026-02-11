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

function bashunit::fail() {
  bashunit::assert::should_skip && return 0

  local message="${1:-${FUNCNAME[1]}}"

  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  bashunit::assert::mark_failed
  bashunit::console_results::print_failure_message "${label}" "$message"
}

function assert_true() {
  bashunit::assert::should_skip && return 0

  local actual="$1"

  # Check for expected literal values first
  case "$actual" in
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

  if [[ $exit_code -ne 0 ]]; then
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

  if [[ $exit_code -eq 0 ]]; then
    bashunit::handle_bool_assertion_failure "command or function with non-zero exit code" "exit code: $exit_code"
  else
    bashunit::state::add_assertions_passed
  fi
}

function bashunit::run_command_or_eval() {
  local cmd="$1"

  local _re='^eval'
  if [[ "$cmd" =~ $_re ]]; then
    eval "${cmd#eval }" &>/dev/null
  else
  _re='^alias'
  if [[ "$(command -v "$cmd")" =~ $_re ]]; then
    eval "$cmd" &>/dev/null
  else
    "$cmd" &>/dev/null
  fi
  return $?
}

function bashunit::handle_bool_assertion_failure() {
  local expected="$1"
  local got="$2"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"

  bashunit::assert::mark_failed
  bashunit::console_results::print_failed_test "$label" "$expected" "but got " "$got"
}

function assert_same() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [[ "$expected" != "$actual" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
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

  local actual_cleaned
  actual_cleaned=$(bashunit::str::strip_ansi "$actual")
  local expected_cleaned
  expected_cleaned=$(bashunit::str::strip_ansi "$expected")

  if [[ "$expected_cleaned" != "$actual_cleaned" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
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

  local actual_cleaned
  actual_cleaned=$(bashunit::str::strip_ansi "$actual")
  local expected_cleaned
  expected_cleaned=$(bashunit::str::strip_ansi "$expected")

  if [[ "$expected_cleaned" == "$actual_cleaned" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected_cleaned}" "but got " "${actual_cleaned}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [[ "$expected" != "" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "to be empty" "but got " "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"

  if [[ "$expected" == "" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
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

  if [[ "$expected" == "$actual" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if ! [[ $actual == *"$expected"* ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_contains_ignore_case() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  # Bash 3.0 compatible: use tr for case-insensitive comparison
  # (shopt nocasematch was introduced in Bash 3.1)
  local expected_lower
  local actual_lower
  expected_lower=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
  actual_lower=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')

  if [[ "$actual_lower" != *"$expected_lower"* ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual == *"$expected"* ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_matches() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if ! [[ "$actual" =~ $expected ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to match" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_not_matches() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ "$actual" =~ $expected ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_exec() {
  bashunit::assert::should_skip && return 0

  local cmd="$1"
  shift

  local expected_exit=0
  local expected_stdout=""
  local expected_stderr=""
  local check_stdout=false
  local check_stderr=false

  while [[ $# -gt 0 ]]; do
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
    *)
      shift
      ;;
    esac
  done

  local stdout_file stderr_file
  stdout_file=$(mktemp)
  stderr_file=$(mktemp)

  eval "$cmd" >"$stdout_file" 2>"$stderr_file"
  local exit_code=$?

  local stdout
  stdout=$(cat "$stdout_file")
  local stderr
  stderr=$(cat "$stderr_file")

  rm -f "$stdout_file" "$stderr_file"

  local expected_desc="exit: $expected_exit"
  local actual_desc="exit: $exit_code"
  local failed=0

  if [[ "$exit_code" -ne "$expected_exit" ]]; then
    failed=1
  fi

  if $check_stdout; then
    expected_desc="$expected_desc"$'\n'"stdout: $expected_stdout"
    actual_desc="$actual_desc"$'\n'"stdout: $stdout"
    if [[ "$stdout" != "$expected_stdout" ]]; then
      failed=1
    fi
  fi

  if $check_stderr; then
    expected_desc="$expected_desc"$'\n'"stderr: $expected_stderr"
    actual_desc="$actual_desc"$'\n'"stderr: $stderr"
    if [[ "$stderr" != "$expected_stderr" ]]; then
      failed=1
    fi
  fi

  if [[ $failed -eq 1 ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "$label" "$expected_desc" "but got " "$actual_desc"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_exit_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  bashunit::assert::should_skip && return 0

  local expected_exit_code="$1"

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_successful_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  bashunit::assert::should_skip && return 0

  local expected_exit_code=0

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_unsuccessful_code() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  bashunit::assert::should_skip && return 0

  if [[ "$actual_exit_code" -eq 0 ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual_exit_code}" "to be non-zero" "but was 0"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_general_error() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  bashunit::assert::should_skip && return 0

  local expected_exit_code=1

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_command_not_found() {
  local actual_exit_code=${3-"$?"} # Capture $? before guard check
  bashunit::assert::should_skip && return 0

  local expected_exit_code=127

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_starts_with() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual != "$expected"* ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to start with" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_not_starts_with() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [[ $actual == "$expected"* ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not start with" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_ends_with() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual != *"$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to end with" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_string_not_ends_with() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local -a actual_arr
  actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual == *"$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to not end with" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_less_than() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -lt "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
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

  if ! [[ "$actual" -le "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
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

  if ! [[ "$actual" -gt "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
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

  if ! [[ "$actual" -ge "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be greater or equal than" "${expected}"
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
  local input_str
  input_str=$(printf '%s\n' ${input_arr+"${input_arr[@]}"})

  if [ -z "$input_str" ]; then
    local actual=0
  else
    local actual
    actual=$(echo "$input_str" | wc -l | tr -d '[:blank:]')
    local additional_new_lines
    additional_new_lines=$(grep -o '\\n' <<<"$input_str" | wc -l | tr -d '[:blank:]')
    actual=$((actual + additional_new_lines))
  fi

  if [[ "$expected" != "$actual" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"

    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${input_str}" \
      "to contain number of lines equal to" "${expected}" \
      "but found" "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}
