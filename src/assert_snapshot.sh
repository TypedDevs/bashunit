#!/bin/bash

function assert_match_snapshot() {
  local actual=$1
  local directory
    directory="./$(dirname "${BASH_SOURCE[1]}")/snapshots"
  local test_file
    test_file="$(helper::normalize_variable_name "$(basename "${BASH_SOURCE[1]}")")"
  local snapshot_name
    snapshot_name="$(helper::normalize_variable_name "${FUNCNAME[1]}").snapshot"
  local snapshot_file
  snapshot_file="${directory}/${test_file}.${snapshot_name}"

  if [[ ! -f "$snapshot_file" ]]; then
    mkdir -p "$directory"
    echo "$actual" > "$snapshot_file"

    state::add_assertions_passed # TODO: state::add_assertions_snapshot
    return
  fi

  local snapshot
  snapshot=$(cat "$snapshot_file")

  if [[ "$actual" != "$snapshot" ]]; then
    local label
    label=$(helper::normalize_test_function_name "${FUNCNAME[1]}")
    local actual_file
    actual_file="${snapshot_file}.tmp"

    state::add_assertions_failed
    # TODO: new console_results::print_failed_test implementation
    printf "${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s
    ${_COLOR_FAINT}Expected to match the snapshot${_COLOR_DEFAULT}\n" "$label"

    if command -v git > /dev//null; then
      echo "$actual" > "$actual_file"
      git diff --no-index --word-diff --color=always "$snapshot_file" "$actual_file" | tail -n +6 | sed "s/^/    /"
      rm "$actual_file"
    fi

    return
  fi

  state::add_assertions_passed
}
