#!/usr/bin/env bash

# shellcheck disable=SC2155

function test_sgr_with_no_arguments_returns_reset() {
  local result
  result=$(bashunit::sgr)

  assert_equals $'\e[0m' "$result"
}

function test_sgr_with_single_code() {
  local result
  result=$(bashunit::sgr 31)

  assert_equals $'\e[31m' "$result"
}

function test_sgr_with_multiple_codes() {
  local result
  result=$(bashunit::sgr 1 31)

  assert_equals $'\e[1;31m' "$result"
}

function test_sgr_with_three_codes() {
  local result
  result=$(bashunit::sgr 1 4 32)

  assert_equals $'\e[1;4;32m' "$result"
}

function test_sgr_bold_code() {
  local result
  result=$(bashunit::sgr 1)

  assert_equals $'\e[1m' "$result"
}

function test_faint_color_uses_bright_black_for_ci_compatibility() {
  # SGR 2 (faint/dim) is not rendered by GitHub Actions log UI.
  # Use SGR 90 (bright black / gray) which renders everywhere.
  assert_same $'\e[90m' "$_BASHUNIT_COLOR_FAINT"
}
