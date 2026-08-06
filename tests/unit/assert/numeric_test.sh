#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_assert_exit_code() {
  function fake_function() {
    exit 0
  }

  assert_empty "$(assert_exit_code "0" "$(fake_function)")"
}

function test_unsuccessful_assert_exit_code() {
  function fake_function() {
    exit 1
  }

  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert exit code" "1" "to be" "0")" \
    "$(assert_exit_code "0" "$(fake_function)")"
}

function test_successful_return_assert_exit_code() {
  function fake_function() {
    return 0
  }

  fake_function

  assert_exit_code "0"
}

function test_unsuccessful_return_assert_exit_code() {
  function fake_function() {
    return 1
  }

  assert_exit_code "1" "$(fake_function)"
}

# `[ -eq ]`/`[ -ne ]` exit with status 2 (not 1) when an operand is not an
# integer. The exit-code assertions must read that as "did not match" and fail;
# reading it as "matched" would count a bogus assertion as passed.
function test_assert_exit_code_fails_when_the_expected_code_is_not_an_integer() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Assert exit code fails when the expected code is not an integer" "0" "to be" "not-a-number")"

  assert_same "$expected" "$(assert_exit_code "not-a-number" "" "0" 2>/dev/null)"
}

function test_assert_exit_code_fails_when_the_actual_code_is_not_an_integer() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Assert exit code fails when the actual code is not an integer" "not-a-number" "to be" "0")"

  assert_same "$expected" "$(assert_exit_code "0" "" "not-a-number" 2>/dev/null)"
}

function test_assert_unsuccessful_code_fails_when_the_actual_code_is_not_an_integer() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Assert unsuccessful code fails when the actual code is not an integer" \
    "not-a-number" "to be non-zero" "but was 0")"

  assert_same "$expected" "$(assert_unsuccessful_code "" "" "not-a-number" 2>/dev/null)"
}

function test_assert_successful_code_fails_when_the_actual_code_is_not_an_integer() {
  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Assert successful code fails when the actual code is not an integer" \
    "not-a-number" "to be exactly" "0")"

  assert_same "$expected" "$(assert_successful_code "" "" "not-a-number" 2>/dev/null)"
}

function test_successful_assert_successful_code() {
  function fake_function() {
    return 0
  }

  assert_empty "$(assert_successful_code "$(fake_function)")"
}

function test_unsuccessful_assert_successful_code() {
  function fake_function() {
    return 2
  }

  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert successful code" "2" "to be exactly" "0")" \
    "$(assert_successful_code "$(fake_function)")"
}

function test_successful_assert_unsuccessful_code() {
  function fake_function() {
    return 2
  }

  assert_empty "$(assert_unsuccessful_code "$(fake_function)")"
}

function test_unsuccessful_assert_unsuccessful_code() {
  function fake_function() {
    return 0
  }

  local expected
  expected="$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert unsuccessful code" "0" "to be non-zero" "but was 0")"
  assert_same "$expected" "$(assert_unsuccessful_code "$(fake_function)")"
}

function test_successful_assert_less_than() {
  assert_empty "$(assert_less_than "3" "1")"
}

function test_unsuccessful_assert_less_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert less than" "3" "to be less than" "1")" \
    "$(assert_less_than "1" "3")"
}

function test_successful_assert_less_or_equal_than_with_a_smaller_number() {
  assert_empty "$(assert_less_or_equal_than "3" "1")"
}

function test_successful_assert_less_or_equal_than_with_an_equal_number() {
  assert_empty "$(assert_less_or_equal_than "3" "3")"
}

function test_unsuccessful_assert_less_or_equal_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert less or equal than" "3" "to be less or equal than" "1")" \
    "$(assert_less_or_equal_than "1" "3")"
}

function test_successful_assert_greater_than() {
  assert_empty "$(assert_greater_than "1" "3")"
}

function test_unsuccessful_assert_greater_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert greater than" "1" "to be greater than" "3")" \
    "$(assert_greater_than "3" "1")"
}

function test_successful_assert_greater_or_equal_than_with_a_smaller_number() {
  assert_empty "$(assert_greater_or_equal_than "1" "3")"
}

function test_successful_assert_greater_or_equal_than_with_an_equal_number() {
  assert_empty "$(assert_greater_or_equal_than "3" "3")"
}

function test_unsuccessful_assert_greater_or_equal_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert greater or equal than" "1" "to be greater or equal than" "3")" \
    "$(assert_greater_or_equal_than "3" "1")"
}

function test_successful_assert_within_delta() {
  assert_empty "$(assert_within_delta "3.14159" "3.14" "0.01")"
}

function test_successful_assert_within_delta_with_a_negative_difference() {
  assert_empty "$(assert_within_delta "100" "105" "10")"
}

function test_successful_assert_within_delta_when_equal() {
  assert_empty "$(assert_within_delta "42" "42" "0")"
}

function test_unsuccessful_assert_within_delta() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert within delta" "105" "to be within 3 of" "100")" \
    "$(assert_within_delta "100" "105" "3")"
}

function test_unsuccessful_assert_within_delta_with_a_non_numeric_value() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
    "Unsuccessful assert within delta with a non numeric value" \
    "abc 105 3" "to all be numeric" "but got a non-numeric value")" \
    "$(assert_within_delta "abc" "105" "3")"
}

# bc cannot parse a leading `+`, but bashunit::assert::_is_numeric accepts one,
# so this pair used to reach the comparison, get an empty result back, and fail
# the assertion. The fixed-point path handles the sign itself.
function test_assert_within_delta_accepts_a_leading_plus() {
  assert_within_delta "+5" "5" "1"
  assert_within_delta "5" "+5" "1"
}

# The fixed-point path deliberately refuses operands it cannot represent exactly
# in 64-bit integer arithmetic and hands them to the bc/awk chain. This one has
# more digits than that path allows, so it exercises the fallback rather than
# the fast path -- and must still give the same answer.
function test_assert_within_delta_falls_back_for_very_high_precision() {
  assert_within_delta "1.00000000000000000001" "1.00000000000000000002" "0.1"
}

function test_assert_within_delta_compares_mixed_precision_operands() {
  assert_within_delta "100" "100.0001" "0.001"
  assert_within_delta "1.000" "1" "0"
  assert_within_delta "3.14159" "3.1416" "0.0001"
}

function test_assert_within_delta_handles_negative_operands() {
  assert_within_delta "-2.5" "-2.4" "0.2"
}
