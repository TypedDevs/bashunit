#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_assert_not_equals() {
  assert_empty "$(assert_not_equals "1" "2")"
}

function test_unsuccessful_assert_not_equals() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert not equals" "1" "but got " "1")" \
    "$(assert_not_equals "1" "1")"
}

function test_unsuccessful_assert_not_equals_with_special_chars() {
  local str1="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} foo"
  local str2="✗ Failed foo"

  assert_equals "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert not equals with special chars" \
    "$str1" "but got " "$str2")" \
    "$(assert_not_equals "$str1" "$str2")"
}

function test_successful_assert_equals() {
  assert_equals "✗ Failed foo" \
    "${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} foo"
}

function test_successful_assert_equals_with_special_chars() {
  local string="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} foo"

  assert_equals "$string" "$string"
}

function test_unsuccessful_assert_equals() {
  local str1="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} str1"
  local str2="${_BASHUNIT_COLOR_FAILED}✗ Failed${_BASHUNIT_COLOR_DEFAULT} str2"

  assert_same "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert equals" \
    "✗ Failed str1" \
    "but got " \
    "✗ Failed str2")" \
    "$(assert_equals "$str1" "$str2")"
}

function test_successful_assert_contains_ignore_case() {
  assert_empty "$(assert_contains_ignore_case "Linux" "GNU/LINUX")"
}

function test_unsuccessful_assert_contains_ignore_case() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert contains ignore case" "GNU/LINUX" "to contain" "Unix")"
  assert_same "$expected" "$(assert_contains_ignore_case "Unix" "GNU/LINUX")"
}

function test_successful_assert_contains() {
  assert_empty "$(assert_contains "Linux" "GNU/Linux")"
}

function test_unsuccessful_assert_contains() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert contains" "GNU/Linux" "to contain" "Unix")" \
    "$(assert_contains "Unix" "GNU/Linux")"
}

function test_successful_assert_not_contains() {
  assert_empty "$(assert_not_contains "Linus" "GNU/Linux")"
}

function test_unsuccessful_assert_not_contains() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert not contains" "GNU/Linux" "to not contain" "Linux")"
  assert_same "$expected" "$(assert_not_contains "Linux" "GNU/Linux")"
}

function test_successful_assert_matches() {
  assert_empty "$(assert_matches ".*Linu*" "GNU/Linux")"
}

function test_unsuccessful_assert_matches() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert matches" "GNU/Linux" "to match" ".*Pinux*")" \
    "$(assert_matches ".*Pinux*" "GNU/Linux")"
}

function test_successful_assert_not_matches() {
  assert_empty "$(assert_not_matches ".*Pinux*" "GNU/Linux")"
}

function test_unsuccessful_assert_not_matches() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert not matches" "GNU/Linux" "to not match" ".*Linu*")"
  assert_same "$expected" "$(assert_not_matches ".*Linu*" "GNU/Linux")"
}

function test_successful_assert_string_starts_with() {
  assert_empty "$(assert_string_starts_with "ho" "house")"
}

function test_unsuccessful_assert_string_starts_with() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert string starts with" "pause" "to start with" "hou")" \
    "$(assert_string_starts_with "hou" "pause")"
}

function test_successful_assert_string_not_starts_with() {
  assert_empty "$(assert_string_not_starts_with "hou" "pause")"
}

function test_unsuccessful_assert_string_not_starts_with() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert string not starts with" "house" "to not start with" "ho")" \
    "$(assert_string_not_starts_with "ho" "house")"
}

function test_successful_assert_string_ends_with() {
  assert_empty "$(assert_string_ends_with "bar" "foobar")"
}

function test_unsuccessful_assert_string_ends_with() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert string ends with" "foobar" "to end with" "foo")" \
    "$(assert_string_ends_with "foo" "foobar")"
}

function test_successful_assert_string_not_ends_with() {
  assert_empty "$(assert_string_not_ends_with "foo" "foobar")"
}

function test_unsuccessful_assert_string_not_ends_with() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert string not ends with" "foobar" "to not end with" "bar")" \
    "$(assert_string_not_ends_with "bar" "foobar")"
}

function test_assert_string_start_end_with_special_chars() {
  assert_empty "$(assert_string_starts_with "foo." "foo.bar")"
  assert_empty "$(assert_string_ends_with ".bar" "foo.bar")"
}

function test_assert_string_start_end_with_special_chars_fail() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Assert string start end with special chars fail" "fooX" "to start with" "foo.")" \
    "$(assert_string_starts_with "foo." "fooX")"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Assert string start end with special chars fail" "fooX" "to end with" ".bar")" \
    "$(assert_string_ends_with ".bar" "fooX")"
}

function test_successful_assert_string_matches_format_with_digit() {
  assert_empty "$(assert_string_matches_format "%d items found" "42 items found")"
}

function test_successful_assert_string_matches_format_with_string() {
  assert_empty "$(assert_string_matches_format "Hello %s" "Hello world")"
}

function test_successful_assert_string_matches_format_with_hex() {
  assert_empty "$(assert_string_matches_format "Color: %x" "Color: ff00ab")"
}

function test_successful_assert_string_matches_format_with_float() {
  assert_empty "$(assert_string_matches_format "Value: %f" "Value: 3.14")"
}

function test_successful_assert_string_matches_format_with_signed_integer() {
  assert_empty "$(assert_string_matches_format "Offset: %i" "Offset: -42")"
}

function test_successful_assert_string_matches_format_with_scientific() {
  assert_empty "$(assert_string_matches_format "Result: %e" "Result: 1.5e10")"
}

function test_successful_assert_string_matches_format_with_literal_percent() {
  assert_empty "$(assert_string_matches_format "100%% done" "100% done")"
}

function test_successful_assert_string_matches_format_with_multiple_placeholders() {
  assert_empty "$(assert_string_matches_format "%s has %d items at %f each" "cart has 5 items at 9.99 each")"
}

function test_unsuccessful_assert_string_matches_format() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert string matches format" \
      "hello world" "to match format" "%d items")" \
    "$(assert_string_matches_format "%d items" "hello world")"
}

function test_successful_assert_string_not_matches_format() {
  assert_empty "$(assert_string_not_matches_format "%d items" "hello world")"
}

function test_unsuccessful_assert_string_not_matches_format() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert string not matches format" \
      "42 items" "to not match format" "%d items")" \
    "$(assert_string_not_matches_format "%d items" "42 items")"
}
