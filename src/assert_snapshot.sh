#!/usr/bin/env bash

function snapshot::match_with_placeholder() {
  local actual="$1"
  local snapshot="$2"
  local placeholder="${BASHUNIT_SNAPSHOT_PLACEHOLDER:-::ignore::}"
  local token="__BASHUNIT_IGNORE__"

  local normalized="${snapshot//$placeholder/$token}"
  local escaped
  escaped=$(printf '%s' "$normalized" | sed -e 's/[.[\\^$*+?{}()|]/\\&/g')
  local regex="^${escaped//$token/(.|\\n)*}$"

  if command -v perl >/dev/null 2>&1; then
    REGEX="$regex" perl -0 -e '
      my $r = $ENV{REGEX};
      my $input = do { local $/; <STDIN> };
      exit($input =~ /$r/s ? 0 : 1);
    ' <<< "$actual"
    return
  fi

  if grep -P '' </dev/null >/dev/null 2>&1; then
    printf '%s\0' "$actual" | grep -Pzo "$regex" >/dev/null
    return
  fi

  # fallback: only supports single-line ignores
  local pattern="${snapshot//$placeholder/.+}"
  pattern=$(printf '%s' "$pattern" | sed -e 's/[][\.^$*+?{}|()]/\\&/g')
  printf '%s' "$actual" | grep -zEq "^${pattern}$"
}

function assert_snapshot::_normalize_snapshot_file() {
  local snapshot_file="$1"
  local funcname="${FUNCNAME[2]}"
  local source_file="${BASH_SOURCE[2]}"
  local directory test_file snapshot_name

  if [[ -n "$snapshot_file" ]]; then
    echo "$snapshot_file"
    return
  fi

  directory="$(dirname "$source_file")/snapshots"
  test_file="$(helper::normalize_variable_name "$(basename "$source_file")")"
  snapshot_name="$(helper::normalize_variable_name "$funcname").snapshot"

  echo "${directory}/${test_file}.${snapshot_name}"
}

function assert_match_snapshot() {
  local actual snapshot_file snapshot
  actual=$(echo -n "$1" | tr -d '\r')
  snapshot_file=$(assert_snapshot::_normalize_snapshot_file "${2-}")

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$(dirname "$snapshot_file")"
    echo "$actual" > "$snapshot_file"
    state::add_assertions_snapshot
    return
  fi

  snapshot=$(tr -d '\r' < "$snapshot_file")
  if ! snapshot::match_with_placeholder "$actual" "$snapshot"; then
    local label
    label=$(helper::normalize_test_function_name "${FUNCNAME[1]}")
    state::add_assertions_failed
    console_results::print_failed_snapshot_test "$label" "$snapshot_file"
    return
  fi

  state::add_assertions_passed
}

function assert_match_snapshot_ignore_colors() {
  local actual snapshot_file snapshot
  actual=$(echo -n "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g' | tr -d '\r')
  snapshot_file=$(assert_snapshot::_normalize_snapshot_file "${2-}")

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$(dirname "$snapshot_file")"
    echo "$actual" > "$snapshot_file"
    state::add_assertions_snapshot
    return
  fi

  snapshot=$(tr -d '\r' < "$snapshot_file")
  if ! snapshot::match_with_placeholder "$actual" "$snapshot"; then
    local label
    label=$(helper::normalize_test_function_name "${FUNCNAME[1]}")
    state::add_assertions_failed
    console_results::print_failed_snapshot_test "$label" "$snapshot_file"
    return
  fi

  state::add_assertions_passed
}
