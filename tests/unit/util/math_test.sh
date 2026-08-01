#!/usr/bin/env bash

# shellcheck disable=SC2155

function test_calculate_integer_addition() {
  local result
  result=$(bashunit::math::calculate "2 + 3")

  assert_equals "5" "$result"
}

function test_calculate_integer_subtraction() {
  local result
  result=$(bashunit::math::calculate "10 - 4")

  assert_equals "6" "$result"
}

function test_calculate_integer_multiplication() {
  local result
  result=$(bashunit::math::calculate "3 * 7")

  assert_equals "21" "$result"
}

function test_calculate_integer_division() {
  local result
  result=$(bashunit::math::calculate "10 / 2")

  assert_equals "5" "$result"
}

function test_calculate_zero_result() {
  local result
  result=$(bashunit::math::calculate "0 + 0")

  assert_equals "0" "$result"
}

function test_calculate_with_bc_for_decimal() {
  if ! bashunit::dependencies::has_bc; then
    bashunit::skip "bc not available"
    return
  fi

  local result
  result=$(bashunit::math::calculate "1.5 + 2.5")

  assert_equals "4.0" "$result"
}

function test_calculate_fallback_to_awk_for_decimal() {
  if ! bashunit::dependencies::has_awk; then
    bashunit::skip "awk not available"
    return
  fi

  bashunit::mock bashunit::dependencies::has_bc false

  local result
  result=$(bashunit::math::calculate "1.5 + 2.5")

  assert_equals "4" "$result"
}

function test_calculate_fallback_to_bash_arithmetic_for_decimal() {
  bashunit::mock bashunit::dependencies::has_bc false
  bashunit::mock bashunit::dependencies::has_awk false

  local result
  result=$(bashunit::math::calculate "10.5 + 20.3")

  assert_equals "30" "$result"
}

function test_shuffle_is_deterministic_for_a_given_seed() {
  local first second
  first=$(printf '%s\n' a b c d e f g h | bashunit::math::shuffle 12345)
  second=$(printf '%s\n' a b c d e f g h | bashunit::math::shuffle 12345)

  assert_equals "$first" "$second"
}

function test_shuffle_differs_for_different_seeds() {
  local one two
  one=$(printf '%s\n' a b c d e f g h | bashunit::math::shuffle 1)
  two=$(printf '%s\n' a b c d e f g h | bashunit::math::shuffle 2)

  assert_not_equals "$one" "$two"
}

function test_shuffle_preserves_all_items() {
  local shuffled_sorted input_sorted
  shuffled_sorted=$(printf '%s\n' a b c d e f g h | bashunit::math::shuffle 7 | sort)
  input_sorted=$(printf '%s\n' a b c d e f g h | sort)

  assert_equals "$input_sorted" "$shuffled_sorted"
}

function test_shuffle_actually_reorders_for_a_known_seed() {
  local original shuffled
  original=$(printf '%s\n' a b c d e f g h)
  shuffled=$(printf '%s\n' a b c d e f g h | bashunit::math::shuffle 12345)

  assert_not_equals "$original" "$shuffled"
}
