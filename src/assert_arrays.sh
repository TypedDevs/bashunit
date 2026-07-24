#!/usr/bin/env bash

function assert_arrays_equal() {
  bashunit::assert::should_skip && return 0

  local -a expected_values=()
  local -a actual_values=()
  local found_separator=false
  local argument

  for argument in "$@"; do
    if [ "$found_separator" = false ] && [ "$argument" = "--" ]; then
      found_separator=true
      continue
    fi

    if [ "$found_separator" = true ]; then
      actual_values[${#actual_values[@]}]="$argument"
    else
      expected_values[${#expected_values[@]}]="$argument"
    fi
  done

  if [ "$found_separator" = false ]; then
    bashunit::assert::fail_with "" "--" "but got " "missing array separator"
    return
  fi

  if [ "${#expected_values[@]}" -ne "${#actual_values[@]}" ]; then
    bashunit::assert::fail_with "" "${expected_values[*]}" "but got " "${actual_values[*]}" \
      "Expected length" "${#expected_values[@]}, actual length ${#actual_values[@]}"
    return
  fi

  local index
  for ((index = 0; index < ${#expected_values[@]}; index++)); do
    if [ "${expected_values[$index]}" != "${actual_values[$index]}" ]; then
      bashunit::assert::fail_with "" "${expected_values[*]}" "but got " "${actual_values[*]}" \
        "Different index" "$index"
      return
    fi
  done

  bashunit::state::add_assertions_passed
}

function assert_array_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  shift

  local -a actual
  actual=("$@")

  case "${actual[*]:-}" in
  *"$expected"*) ;;
  *)
    bashunit::assert::fail_with "" "${actual[*]}" "to contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_array_length() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  shift

  # Use $# / $* rather than building an array: on Bash 3.0 under `set -u`,
  # expanding "$@" into an array with zero elements is an unbound-variable error.
  local actual_length="$#"

  if [ "$expected" != "$actual_length" ]; then
    bashunit::assert::fail_with "" "$*" "to have length ${expected}" "but got ${actual_length}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_array_not_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  shift
  local -a actual
  actual=("$@")

  case "${actual[*]:-}" in
  *"$expected"*)
    bashunit::assert::fail_with "" "${actual[*]}" "to not contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}
