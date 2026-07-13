#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  FIXTURE="./tests/acceptance/fixtures/diff/multiline_diff.sh"
}

function test_multiline_failure_renders_a_word_diff() {
  if ! bashunit::dependencies::has_git; then
    bashunit::skip "git not available" && return
  fi

  local output
  output=$(./bashunit --no-parallel --no-color --skip-env-file --filter multiline "$FIXTURE" 2>&1) || true

  assert_contains "[-beta-]{+DELTA+}" "$output"
  assert_contains "alpha…" "$output"
}

function test_no_diff_env_keeps_full_multiline_values() {
  local output
  output=$(BASHUNIT_NO_DIFF=true ./bashunit --no-parallel --no-color --skip-env-file --filter multiline "$FIXTURE" 2>&1) || true

  assert_not_contains "[-beta-]" "$output"
  assert_not_contains "alpha…" "$output"
  assert_contains "beta" "$output"
  assert_contains "gamma" "$output"
}

function test_single_line_failure_stays_inline_without_diff() {
  local output
  output=$(./bashunit --no-parallel --no-color --skip-env-file --filter single_line "$FIXTURE" 2>&1) || true

  assert_contains "'expected_value'" "$output"
  assert_contains "'actual_value'" "$output"
  assert_not_contains "[-" "$output"
}
