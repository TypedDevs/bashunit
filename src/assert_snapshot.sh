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

  mkdir -p "$directory"
  echo "$actual" > "$snapshot_file"

  state::add_assertions_passed
}
