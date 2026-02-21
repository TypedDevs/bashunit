#!/usr/bin/env bash

function bashunit::duration::measure_ms() {
  local command="$1"

  local start_ns
  start_ns=$(bashunit::clock::now)

  eval "$command" >/dev/null 2>&1

  local end_ns
  end_ns=$(bashunit::clock::now)

  local elapsed_ms
  elapsed_ms=$(bashunit::math::calculate "($end_ns - $start_ns) / 1000000" | awk '{printf "%.0f", $1}')

  echo "$elapsed_ms"
}

function assert_duration() {
  bashunit::assert::should_skip && return 0

  local command="$1"
  local threshold_ms="$2"

  local elapsed_ms
  elapsed_ms=$(bashunit::duration::measure_ms "$command")

  if [ "$elapsed_ms" -gt "$threshold_ms" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${threshold_ms}" "to complete within (ms)" "${command}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_duration_less_than() {
  bashunit::assert::should_skip && return 0

  local command="$1"
  local threshold_ms="$2"

  local elapsed_ms
  elapsed_ms=$(bashunit::duration::measure_ms "$command")

  if [ "$elapsed_ms" -ge "$threshold_ms" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${threshold_ms}" "to complete within (ms)" "${command}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_duration_greater_than() {
  bashunit::assert::should_skip && return 0

  local command="$1"
  local threshold_ms="$2"

  local elapsed_ms
  elapsed_ms=$(bashunit::duration::measure_ms "$command")

  if [ "$elapsed_ms" -le "$threshold_ms" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${threshold_ms}" "to take at least (ms)" "${command}"
    return
  fi

  bashunit::state::add_assertions_passed
}
