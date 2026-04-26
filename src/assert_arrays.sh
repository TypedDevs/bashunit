#!/usr/bin/env bash

function assert_arrays_equal() {
  bashunit::assert::should_skip && return 0

  local label
  label="$(bashunit::assert::label)"

  local -a expected_values
  local -a actual_values
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
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "$label" "--" "but got " "missing array separator"
    return
  fi

  if [ "${#expected_values[@]}" -ne "${#actual_values[@]}" ]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test \
      "$label" "${expected_values[*]}" "but got " "${actual_values[*]}" \
      "Expected length" "${#expected_values[@]}, actual length ${#actual_values[@]}"
    return
  fi

  local index
  for ((index = 0; index < ${#expected_values[@]}; index++)); do
    if [ "${expected_values[$index]}" != "${actual_values[$index]}" ]; then
      bashunit::assert::mark_failed
      bashunit::console_results::print_failed_test \
        "$label" "${expected_values[*]}" "but got " "${actual_values[*]}" \
        "Different index" "$index"
      return
    fi
  done

  bashunit::state::add_assertions_passed
}

function assert_array_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  shift

  local -a actual
  actual=("$@")

  case "${actual[*]:-}" in
  *"$expected"*)
    ;;
  *)
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual[*]}" "to contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}

function assert_array_not_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  shift
  local -a actual
  actual=("$@")

  case "${actual[*]:-}" in
  *"$expected"*)
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
    ;;
  esac

  bashunit::state::add_assertions_passed
}
