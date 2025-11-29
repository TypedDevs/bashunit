#!/usr/bin/env bash
set -euo pipefail


function test_bashunit_should_display_version() {
  local fixture
  fixture=$(printf "\e[1m\e[32mbashunit\e[0m - %s" "$BASHUNIT_VERSION")

  todo "Add snapshots with regex to assert this test (part of the output changes every version)"
  assert_contains "$fixture" "$(./bashunit --version)"
  assert_successful_code "$(./bashunit --version)"
}

function test_bashunit_should_display_help() {
  assert_match_snapshot "$(./bashunit --help)"
  assert_successful_code "$(./bashunit --help)"
}

function test_bashunit_should_display_all_assert_docs() {
  assert_match_snapshot "$(./bashunit doc)"
  assert_successful_code "$(./bashunit doc)"
}

function test_bashunit_should_display_filtered_assert_docs() {
  assert_match_snapshot "$(./bashunit doc equals)"
  assert_successful_code "$(./bashunit doc equals)"
}

function test_built_binary_should_display_docs_without_file_access() {
  if [[ ! -f "bin/bashunit" ]]; then
    skip "Built binary not found - run ./build.sh first"
    return
  fi

  local output
  output=$(bin/bashunit doc assert_true 2>&1)

  assert_successful_code
  assert_contains "assert_true" "$output"
  assert_contains "bool|function|command" "$output"
}

function test_built_binary_docs_should_match_dev_docs() {
  if [[ ! -f "bin/bashunit" ]]; then
    skip "Built binary not found - run ./build.sh first"
    return
  fi

  local dev_output built_output

  dev_output=$(./bashunit doc equals)
  built_output=$(bin/bashunit doc equals)

  assert_same "$dev_output" "$built_output"
}
