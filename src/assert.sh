#!/bin/bash

function fail() {
  local message="${1:-${FUNCNAME[1]}}"

  local label
  label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
  state::add_assertions_failed
  console_results::print_failure_message "${label}" "$message"
}

function assert_true() {
  local actual="$1"

  # Check for expected literal values first
  case "$actual" in
    "true"|"0") state::add_assertions_passed; return ;;
    "false"|"1") handle_bool_assertion_failure "true or 0" "$actual"; return ;;
  esac

  # Run command or eval and check the exit code
  run_command_or_eval "$actual"
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    handle_bool_assertion_failure "command or function with zero exit code" "exit code: $exit_code"
  else
    state::add_assertions_passed
  fi
}

function assert_false() {
  local actual="$1"

  # Check for expected literal values first
  case "$actual" in
    "false"|"1") state::add_assertions_passed; return ;;
    "true"|"0") handle_bool_assertion_failure "false or 1" "$actual"; return ;;
  esac

  # Run command or eval and check the exit code
  run_command_or_eval "$actual"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    handle_bool_assertion_failure "command or function with non-zero exit code" "exit code: $exit_code"
  else
    state::add_assertions_passed
  fi
}

function run_command_or_eval() {
  local cmd="$1"

  if [[ "$cmd" =~ ^eval ]]; then
    eval "${cmd#eval }" &> /dev/null
  elif [[ "$(command -v "$cmd")" =~ ^alias ]]; then
    eval "$cmd" &> /dev/null
  else
    "$cmd" &> /dev/null
  fi
  return $?
}

function handle_bool_assertion_failure() {
  local expected="$1"
  local got="$2"
  local label
  label="$(helper::normalize_test_function_name "${FUNCNAME[2]}")"

  state::add_assertions_failed
  console_results::print_failed_test "$label" "$expected" "but got " "$got"
}

function assert_same() {
  local expected="$1"
  local actual="$2"

  if [[ "$expected" != "$actual" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "but got " "${actual}"
    return
  fi

  state::add_assertions_passed
}

function assert_equals() {
  local expected="$1"
  local actual="$2"

  # Remove ANSI escape sequences (color codes)
  local actual_cleaned
  actual_cleaned=$(echo -e "$actual" | sed -r "s/\x1B\[[0-9;]*[mK]//g")
  local expected_cleaned
  expected_cleaned=$(echo -e "$expected" | sed -r "s/\x1B\[[0-9;]*[mK]//g")

  # Remove all control characters and whitespace (optional, depending on your needs)
  actual_cleaned=$(echo "$actual_cleaned" | tr -d '[:cntrl:]')
  expected_cleaned=$(echo "$expected_cleaned" | tr -d '[:cntrl:]')

  if [[ "$expected_cleaned" != "$actual_cleaned" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected_cleaned}" "but got " "${actual_cleaned}"
    return
  fi

  state::add_assertions_passed
}

function assert_empty() {
  local expected="$1"

  if [[ "$expected" != "" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "to be empty" "but got " "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_not_empty() {
  local expected="$1"

  if [[ "$expected" == "" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "to not be empty" "but got " "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_not_same() {
  local expected="$1"
  local actual="$2"

  if [[ "$expected" == "$actual" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "but got " "${actual}"
    return
  fi

  state::add_assertions_passed
}

function assert_contains() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if ! [[ $actual == *"$expected"* ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_contains_ignore_case() {
  local expected="$1"
  local actual="$2"

  shopt -s nocasematch

  if ! [[ $actual =~ $expected ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    shopt -u nocasematch
    return
  fi

  shopt -u nocasematch
  state::add_assertions_passed
}

function assert_not_contains() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual == *"$expected"* ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not contain" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_matches() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if ! [[ $actual =~ $expected ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to match" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_not_matches() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual =~ $expected ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_exit_code() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code="$1"

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_successful_code() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=0

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_general_error() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=1

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_command_not_found() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=127

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_starts_with() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if ! [[ $actual =~ ^"$expected"* ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to start with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_not_starts_with() {
  local expected="$1"
  local actual="$2"

  if [[ $actual =~ ^"$expected"* ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not start with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_ends_with() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if ! [[ $actual =~ .*"$expected"$ ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to end with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_not_ends_with() {
  local expected="$1"
  local actual_arr=("${@:2}")
  local actual
  actual=$(printf '%s\n' "${actual_arr[@]}")

  if [[ $actual =~ .*"$expected"$ ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not end with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_less_than() {
  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -lt "$expected" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be less than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_less_or_equal_than() {
  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -le "$expected" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be less or equal than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_greater_than() {
  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -gt "$expected" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be greater than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_greater_or_equal_than() {
  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -ge "$expected" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be greater or equal than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_line_count() {
  local expected="$1"
  local input_arr=("${@:2}")
  local input_str
  input_str=$(printf '%s\n' "${input_arr[@]}")

  if [ -z "$input_str" ]; then
    local actual=0
  else
    local actual
    actual=$(echo "$input_str" | wc -l | tr -d '[:blank:]')
    additional_new_lines=$(grep -o '\\n' <<< "$input_str" | wc -l | tr -d '[:blank:]')
    ((actual+=additional_new_lines))
  fi

  if [[ "$expected" != "$actual" ]]; then
    local label
    label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"

    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${input_str}"\
      "to contain number of lines equal to" "${expected}"\
      "but found" "${actual}"
    return
  fi

  state::add_assertions_passed
}
