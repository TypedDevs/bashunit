#!/usr/bin/env bash

function bashunit::date::to_epoch() {
  local input="$1"

  # Already epoch seconds (all digits)
  case "$input" in
  *[!0-9]*) ;; # contains non-digits, continue to ISO parsing
  *)
    echo "$input"
    return 0
    ;;
  esac

  # Handle Z (UTC) suffix explicitly: BusyBox needs TZ=UTC, BSD needs +0000
  case "$input" in
  *Z)
    local utc_input="${input%Z}"
    local utc_norm="${utc_input/T/ }"
    local epoch
    # GNU/BusyBox: parse in explicit UTC
    epoch=$(TZ=UTC date -d "$utc_input" +%s 2>/dev/null) && { echo "$epoch"; return 0; }
    epoch=$(TZ=UTC date -d "$utc_norm" +%s 2>/dev/null) && { echo "$epoch"; return 0; }
    # BSD: use +0000 offset which %z understands
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "${utc_input}+0000" +%s 2>/dev/null) && { echo "$epoch"; return 0; }
    echo "$input"
    return 1
    ;;
  esac

  # Normalize ISO 8601: replace T with space, strip tz offset
  local normalized="$input"
  normalized="${normalized/T/ }"
  # Strip timezone offset (+HHMM or -HHMM) at end for initial parsing
  case "$normalized" in
  *[+-][0-9][0-9][0-9][0-9])
    normalized="${normalized%[+-][0-9][0-9][0-9][0-9]}"
    ;;
  esac

  # Format conversion (GNU vs BSD date)
  local epoch
  # Try GNU date first (-d flag) with original input
  epoch=$(date -d "$input" +%s 2>/dev/null) && {
    echo "$epoch"
    return 0
  }
  # If input has timezone offset, parse in UTC and adjust manually (BusyBox)
  case "$input" in
  *[+-][0-9][0-9][0-9][0-9])
    epoch=$(TZ=UTC date -d "$normalized" +%s 2>/dev/null) && {
      local ilen=${#input}
      local ostart=$((ilen - 5))
      local osign="${input:$ostart:1}"
      local ohh="${input:$((ostart + 1)):2}"
      local omm="${input:$((ostart + 3)):2}"
      local osecs=$(( (10#$ohh * 3600) + (10#$omm * 60) ))
      if [ "$osign" = "+" ]; then
        osecs=$(( -osecs ))
      fi
      echo $(( epoch + osecs ))
      return 0
    }
    ;;
  esac
  # Try GNU date with normalized (space-separated) input
  if [ "$normalized" != "$input" ]; then
    epoch=$(date -d "$normalized" +%s 2>/dev/null) && {
      echo "$epoch"
      return 0
    }
  fi
  # Try BSD date (-j -f flag) with ISO 8601 datetime + timezone offset
  epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$input" +%s 2>/dev/null) && {
    echo "$epoch"
    return 0
  }
  # Try BSD date with ISO 8601 datetime format
  epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$input" +%s 2>/dev/null) && {
    echo "$epoch"
    return 0
  }
  # Try BSD date with space-separated datetime format
  epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$input" +%s 2>/dev/null) && {
    echo "$epoch"
    return 0
  }
  # Try BSD date with date-only format (append midnight for deterministic results)
  epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$input 00:00:00" +%s 2>/dev/null) && {
    echo "$epoch"
    return 0
  }

  # Unsupported format
  echo "$input"
  return 1
}

function assert_date_equals() {
  bashunit::assert::should_skip && return 0

  local expected
  expected="$(bashunit::date::to_epoch "$1")"
  local actual
  actual="$(bashunit::date::to_epoch "$2")"

  if [ "$actual" -ne "$expected" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be equal to" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_before() {
  bashunit::assert::should_skip && return 0

  local expected
  expected="$(bashunit::date::to_epoch "$1")"
  local actual
  actual="$(bashunit::date::to_epoch "$2")"

  if [ "$actual" -ge "$expected" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be before" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_after() {
  bashunit::assert::should_skip && return 0

  local expected
  expected="$(bashunit::date::to_epoch "$1")"
  local actual
  actual="$(bashunit::date::to_epoch "$2")"

  if [ "$actual" -le "$expected" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be after" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_within_range() {
  bashunit::assert::should_skip && return 0

  local from
  from="$(bashunit::date::to_epoch "$1")"
  local to
  to="$(bashunit::date::to_epoch "$2")"
  local actual
  actual="$(bashunit::date::to_epoch "$3")"

  if [ "$actual" -lt "$from" ] || [ "$actual" -gt "$to" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be between" "${from} and ${to}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_within_delta() {
  bashunit::assert::should_skip && return 0

  local expected
  expected="$(bashunit::date::to_epoch "$1")"
  local actual
  actual="$(bashunit::date::to_epoch "$2")"
  local delta="$3"

  local diff=$((actual - expected))
  if [ "$diff" -lt 0 ]; then
    diff=$((-diff))
  fi

  if [ "$diff" -gt "$delta" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be within" "${delta} seconds of ${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}
