#!/usr/bin/env bash

# shellcheck disable=SC2155

function test_strip_ansi_plain_text_is_unchanged() {
  assert_same "hello world" "$(bashunit::str::strip_ansi "hello world")"
}

function test_strip_ansi_removes_color_codes() {
  local colored=$(printf "\033[32mok\033[0m")

  assert_same "ok" "$(bashunit::str::strip_ansi "$colored")"
}

function test_strip_ansi_removes_control_chars() {
  local tabbed=$(printf "a\tb")

  assert_same "ab" "$(bashunit::str::strip_ansi "$tabbed")"
}

function test_strip_ansi_empty_input() {
  assert_same "" "$(bashunit::str::strip_ansi "")"
}

function test_rpad_default_width_padding_and_empty_left_text() {
  export TERMINAL_WIDTH=30

  local actual=$(bashunit::str::rpad "" "right-text")

  assert_same "                    right-text" "$actual"
}

function test_rpad_default_width_padding() {
  export TERMINAL_WIDTH=30

  local actual=$(bashunit::str::rpad "input" "right-text")

  assert_same "input               right-text" "$actual"
}

function test_rpad_custom_width_padding_1_digit() {
  local actual=$(bashunit::str::rpad "input" "1" 20)

  assert_same "input              1" "$actual"
}

function test_rpad_custom_width_padding_2_digit() {
  local actual=$(bashunit::str::rpad "input" "10" 20)

  assert_same "input             10" "$actual"
}

function test_rpad_custom_width_padding_3_digit() {
  local actual=$(bashunit::str::rpad "input" "100" 20)

  assert_same "input            100" "$actual"
}

function test_rpad_custom_width_padding_text_too_long() {
  local actual=$(bashunit::str::rpad "very long text too large" "100" 20)

  assert_same "very long tex... 100" "$actual"
}

function test_rpad_custom_width_padding_text_too_long_and_special_chars() {
  local txt=$(printf "%s%s%s%s" "$_BASHUNIT_COLOR_PASSED" "ok: " "$_BASHUNIT_COLOR_DEFAULT" "very long text as well")
  local actual=$(bashunit::str::rpad "$txt" "100" 20)

  assert_same \
    "$(printf "%sok: %svery long... 100" "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_DEFAULT")" \
    "$actual"
}

function test_rpad_does_not_exit_under_set_e() {
  # ((i++)) when i=0 evaluates to 0 (falsy) causing exit code 1;
  # under set -e this silently terminates the function (#618)
  local actual
  actual=$(
    set -e
    bashunit::str::rpad "input" "1" 20
  )

  assert_same "input              1" "$actual"
}

function test_rpad_width_smaller_than_right_word() {
  local actual=$(bashunit::str::rpad "foo" "verylongword" 5)

  assert_same "... verylongword" "$actual"
}
