#!/usr/bin/env bash

function test_colors_disabled_via_env() {
  local output
  output=$(bash -c '
    export BASHUNIT_COLOR=false
    source "$BASHUNIT_ROOT_DIR/src/globals.sh"
    source "$BASHUNIT_ROOT_DIR/src/env.sh"
    source "$BASHUNIT_ROOT_DIR/src/colors.sh"
    printf "%s%s%s" "$_COLOR_PASSED" "$_COLOR_FAILED" "$_COLOR_DEFAULT"
  ')
  assert_empty "$output"
}

function test_colors_enabled_by_default() {
  local output
  output=$(bash -c '
    unset BASHUNIT_COLOR
    source "$BASHUNIT_ROOT_DIR/src/globals.sh"
    source "$BASHUNIT_ROOT_DIR/src/env.sh"
    source "$BASHUNIT_ROOT_DIR/src/colors.sh"
    printf "%s" "$_COLOR_PASSED"
  ')
  assert_not_empty "$output"
}
