#!/usr/bin/env bash
# shellcheck disable=SC2317

function tear_down() {
  unset BASHUNIT_NO_DIFF
}

function test_first_line_ellipsis_leaves_single_line_untouched() {
  assert_same "hello" "$(bashunit::console_results::first_line_ellipsis "hello")"
}

function test_first_line_ellipsis_truncates_multiline_to_first_line() {
  local value
  value=$(printf 'first\nsecond\nthird')
  assert_same "first…" "$(bashunit::console_results::first_line_ellipsis "$value")"
}

function test_is_diff_enabled_by_default() {
  unset BASHUNIT_NO_DIFF
  local rc=0
  bashunit::env::is_diff_enabled || rc=$?
  assert_same 0 "$rc"
}

function test_is_diff_disabled_with_no_diff_env() {
  export BASHUNIT_NO_DIFF=true
  local rc=0
  bashunit::env::is_diff_enabled || rc=$?
  assert_same 1 "$rc"
}

function test_render_diff_is_empty_for_identical_files() {
  if ! bashunit::dependencies::has_git; then
    bashunit::skip "git not available" && return
  fi
  local a b
  a=$(bashunit::temp_file diff_a)
  b=$(bashunit::temp_file diff_b)
  printf 'same\ncontent\n' >"$a"
  printf 'same\ncontent\n' >"$b"

  assert_empty "$(bashunit::console_results::render_diff "$a" "$b")"
  rm -f "$a" "$b"
}

function test_render_diff_shows_changed_tokens_without_color() {
  if ! bashunit::dependencies::has_git; then
    bashunit::skip "git not available" && return
  fi
  export BASHUNIT_NO_COLOR=true
  local a b
  a=$(bashunit::temp_file diff_a)
  b=$(bashunit::temp_file diff_b)
  printf 'alpha\nbeta\ngamma\n' >"$a"
  printf 'alpha\nDELTA\ngamma\n' >"$b"

  local output
  output=$(bashunit::console_results::render_diff "$a" "$b")

  assert_contains "beta" "$output"
  assert_contains "DELTA" "$output"
  rm -f "$a" "$b"
  unset BASHUNIT_NO_COLOR
}
