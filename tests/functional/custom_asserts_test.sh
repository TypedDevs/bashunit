#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  # shellcheck disable=SC1091
  source "$(bashunit::current_dir)/custom_asserts.sh"
}

function test_assert_foo_passed() {
  assert_assertion_passes assert_foo "foo"
}

function test_assert_foo_failed() {
  assert_assertion_fails assert_foo "bar"
}

function test_assert_foo_failure_reports_the_expected_and_actual_values() {
  assert_assertion_fails_with "Expected 'foo'" assert_foo "bar"
  assert_assertion_fails_with "'bar'" assert_foo "bar"
}

function test_assert_foo_failure_is_labelled_with_the_test_name() {
  assert_assertion_fails_with \
    "Assert foo failure is labelled with the test name" assert_foo "bar"
}

function test_assert_positive_number_passed() {
  assert_assertion_passes assert_positive_number "1"
}

function test_assert_positive_number_failed() {
  assert_assertion_fails assert_positive_number "0"
}

function test_assert_positive_number_uses_its_own_failure_condition_message() {
  assert_assertion_fails_with "got '0'" assert_positive_number "0"
}

function test_assert_that_positive_number_passed() {
  assert_assertion_passes assert_that_positive_number "1"
}

function test_assert_that_positive_number_failed() {
  assert_assertion_fails_with "Expected 'positive number'" assert_that_positive_number "0"
}

function test_assert_labelled_foo_passed() {
  assert_assertion_passes assert_labelled_foo "foo"
}

function test_assert_labelled_foo_names_itself_instead_of_the_test() {
  assert_assertion_fails_with "Assert labelled foo" assert_labelled_foo "bar"

  assert_not_contains \
    "Assert labelled foo names itself instead of the test" \
    "$_BASHUNIT_ASSERT_INNER_OUTPUT_OUT"
}
