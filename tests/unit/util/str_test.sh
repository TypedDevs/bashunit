#!/usr/bin/env bash

# shellcheck disable=SC2155

function test_strip_ansi_plain_text_is_unchanged() {
  assert_same "hello world" "$(bashunit::str::strip_ansi "hello world")"
}

function test_strip_ansi_to_slot_plain_text_fast_path() {
  bashunit::str::strip_ansi_to_slot "hello world"

  assert_same "hello world" "$_BASHUNIT_STR_STRIPPED_OUT"
}

function test_strip_ansi_to_slot_removes_color_codes() {
  local colored=$(printf "\033[32mok\033[0m")

  bashunit::str::strip_ansi_to_slot "$colored"

  assert_same "ok" "$_BASHUNIT_STR_STRIPPED_OUT"
}

function test_strip_ansi_to_slot_does_not_shadow_caller_input_local() {
  # Regression: passing a value equal to the helper's own internal local name
  # must round-trip unchanged (dynamic-scoping trap, see bash-style.md).
  local input="caller-owned"

  bashunit::str::strip_ansi_to_slot "input"

  assert_same "input" "$_BASHUNIT_STR_STRIPPED_OUT"
  assert_same "caller-owned" "$input"
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

function test_strip_ansi_glob_chars_are_unchanged() {
  # Glob metacharacters must not trigger the control-char slow path
  assert_same "a*b?c[d]" "$(bashunit::str::strip_ansi "a*b?c[d]")"
}

function test_strip_ansi_percent_is_unchanged() {
  assert_same "100% done" "$(bashunit::str::strip_ansi "100% done")"
}

function test_strip_ansi_keeps_a_literal_backslash_escape() {
  # A literal backslash sends input through the slow path, which used to run
  # `echo -e` and expand "\t" into a tab that sed then stripped -- so
  # assert_equals could not tell `a\tb` from a real tab, nor `C:\` from `C:\\`
  # (#1108). Normalizing ANSI and control bytes must not rewrite the text.
  assert_same "col1\\tcol2" "$(bashunit::str::strip_ansi "col1\\tcol2")"
}

function test_strip_ansi_still_strips_a_real_control_character() {
  local with_tab
  with_tab="$(printf 'col1\tcol2')"

  assert_same "col1col2" "$(bashunit::str::strip_ansi "$with_tab")"
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

function test_strip_ansi_to_slot_removes_erase_codes_and_control_chars() {
  local input
  input="$(printf '\033[2K\033[1;32mok\033[0m\tdone\r')"

  bashunit::str::strip_ansi_to_slot "$input"

  assert_same "okdone" "$_BASHUNIT_STR_STRIPPED_OUT"
}

function test_strip_ansi_to_slot_long_input_matches_short_path() {
  # Inputs beyond the pure-bash size guard take the sed path; both paths must
  # produce identical output for the same (repeated) colored payload.
  local unit="\033[31mred\033[0m plain "
  local long_input=""
  local short_expected=""
  local n=100
  while [ "$n" -gt 0 ]; do
    long_input="${long_input}${unit}"
    short_expected="${short_expected}red plain "
    n=$((n - 1))
  done
  long_input="$(printf '%b' "$long_input")"

  bashunit::str::strip_ansi_to_slot "$long_input"

  assert_same "$short_expected" "$_BASHUNIT_STR_STRIPPED_OUT"
}

# rpad runs once per passing test on Bash 5, where per-test timing is on, and
# the `$( )` around it was the whole cost -- the function itself is already
# fork-free (#1348). The slot variant has to produce exactly what the capture
# produced, trailing newline stripped, on every shape rpad handles.
function _rpad_slot_matches_capture() { # $1..$3 = rpad arguments
  local captured
  captured="$(bashunit::str::rpad "$@")"
  bashunit::str::rpad_to_slot "$@"
  assert_same "$captured" "$_BASHUNIT_STR_RPAD_OUT"
}

function test_rpad_to_slot_matches_rpad_for_plain_text() {
  _rpad_slot_matches_capture "input" "right-text" 40
}

function test_rpad_to_slot_matches_rpad_for_empty_left_text() {
  _rpad_slot_matches_capture "" "right-text" 40
}

function test_rpad_to_slot_matches_rpad_for_ansi_coloured_text() {
  _rpad_slot_matches_capture "$(printf '\033[32mgreen\033[0m text')" "12ms" 40
}

# strip_ansi_to_slot changes strategy above 1024 characters, and rpad measures
# the visible width through it.
function test_rpad_to_slot_matches_rpad_for_a_long_string() {
  local long=""
  local i=0
  while [ $i -lt 130 ]; do
    long="${long}0123456789"
    i=$((i + 1))
  done

  _rpad_slot_matches_capture "$long" "12ms" 60
}

function test_rpad_to_slot_matches_rpad_when_truncating() {
  _rpad_slot_matches_capture "a-fairly-long-test-name-that-will-not-fit" "12ms" 20
}

function test_rpad_to_slot_matches_rpad_when_width_is_smaller_than_right_word() {
  _rpad_slot_matches_capture "input" "right-text" 3
}

# --- the version-gated lpad helper ----------------------------------------
#
# The first gated helper in the tree (#1352). A gate may change speed and must
# never change what comes out, so these check both halves: that the running
# shell got the body its tier says it should, and that the body agrees with the
# `printf` it replaced over every shape the callers use.

function test_the_bash_31_flag_matches_the_running_shell() {
  local expected=0
  if [ "${BASH_VERSINFO[0]:-0}" -gt 3 ]; then
    expected=1
  elif [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 1 ]; then
    expected=1
  fi

  assert_same "$expected" "$_BASHUNIT_BASH_GE_31"
}

# A gate that silently always falls back would pass every equivalence test
# while delivering none of the speed, so the selected body is asserted too.
# Introspected with `type`, not `declare -f`: real Bash 3.0 refuses a `::` name
# there.
function test_lpad_selects_the_body_its_tier_calls_for() {
  local body
  body="$(type bashunit::str::lpad_to_slot 2>/dev/null)"

  if [ "$_BASHUNIT_BASH_GE_31" = 1 ]; then
    assert_contains "printf -v" "$body"
  else
    assert_not_contains "printf -v" "$body"
  fi
}

function test_lpad_matches_the_printf_it_replaced() {
  local shape width value expected
  local mismatches=""

  for shape in "14:≤ 5" "12:> 5" "6:12.5" "3:abcdef" "1:x" "8:" "4:  "; do
    width=${shape%%:*}
    value=${shape#*:}
    expected="$(printf "%${width}s" "$value")"
    bashunit::str::lpad_to_slot "$width" "$value"
    if [ "$expected" != "$_BASHUNIT_STR_LPAD_OUT" ]; then
      mismatches="$mismatches [$width|$value]"
    fi
  done

  assert_empty "$mismatches"
}

function test_lpad_right_aligns_within_the_field() {
  bashunit::str::lpad_to_slot 5 "ab"

  assert_same "   ab" "$_BASHUNIT_STR_LPAD_OUT"
}

# A value longer than the field is printed whole, the way printf does it.
function test_lpad_does_not_truncate_a_value_wider_than_the_field() {
  bashunit::str::lpad_to_slot 2 "abcdef"

  assert_same "abcdef" "$_BASHUNIT_STR_LPAD_OUT"
}
