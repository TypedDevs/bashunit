#!/usr/bin/env bash
set -euo pipefail

function test_bashunit_should_display_version() {
  local fixture
  fixture=$(printf "\e[1m\e[32mbashunit\e[0m - %s" "$BASHUNIT_VERSION")

  bashunit::todo "Add snapshots with regex to assert this test (part of the output changes every version)"
  local output exit_code=0
  output="$(./bashunit --version)" || exit_code=$?
  assert_contains "$fixture" "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_bashunit_should_display_help() {
  local output exit_code=0
  output="$(./bashunit --help)" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_bashunit_should_display_all_assert_docs() {
  local output exit_code=0
  output="$(./bashunit doc)" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_bashunit_should_display_filtered_assert_docs() {
  local output exit_code=0
  output="$(./bashunit doc equals)" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_built_binary_should_display_docs_without_file_access() {
  local built_bin="${BASHUNIT_BUILD_DIR:-bin}/bashunit"

  if [[ ! -f "$built_bin" ]]; then
    bashunit::skip "Built binary not found - run ./build.sh first"
    return
  fi

  local output
  output=$("$built_bin" doc assert_true 2>&1)

  assert_successful_code
  assert_contains "assert_true" "$output"
  assert_contains "bool|function|command" "$output"
}

function test_built_binary_docs_should_match_dev_docs() {
  local built_bin="${BASHUNIT_BUILD_DIR:-bin}/bashunit"

  if [[ ! -f "$built_bin" ]]; then
    bashunit::skip "Built binary not found - run ./build.sh first"
    return
  fi

  # The binary is gitignored, so switching branches leaves whatever the last
  # build produced. Comparing a stale artifact against current docs fails for
  # a reason that has nothing to do with the change under test, so say what to
  # do instead (#1117).
  if [ "docs/assertions.md" -nt "$built_bin" ]; then
    bashunit::skip "Built binary is older than docs/assertions.md - run ./build.sh"
    return
  fi

  local dev_output built_output

  dev_output=$(./bashunit doc equals)
  built_output=$("$built_bin" doc equals)

  assert_same "$dev_output" "$built_output"
}
