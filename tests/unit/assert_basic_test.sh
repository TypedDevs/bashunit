#!/usr/bin/env bash
# shellcheck disable=SC2327
# shellcheck disable=SC2328
# shellcheck disable=SC2329

function test_successful_fail() {
  assert_empty "$(true || bashunit::fail "This cannot fail")"
}

function test_unsuccessful_fail() {
  assert_same "$(bashunit::console_results::print_failure_message \
    "Unsuccessful fail" "Failure message")" \
    "$(bashunit::fail "Failure message")"
}

# @data_provider provider_successful_assert_true
function test_successful_assert_true() {
  # shellcheck disable=SC2086
  assert_empty "$(assert_true $1)"
}

function provider_successful_assert_true() {
  bashunit::data_set true
  bashunit::data_set "true"
  bashunit::data_set 0
}

function test_unsuccessful_assert_true() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert true" \
    "true or 0" \
    "but got " "false")" \
    "$(assert_true false)"
}

function test_unsuccessful_assert_true_with_empty_value() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert true with empty value" \
    "true or 0" \
    "but got " "")" \
    "$(assert_true "")"
}

function test_successful_assert_true_on_function() {
  assert_empty "$(assert_true ls)"
}

function test_run_command_or_eval_runs_alias() {
  shopt -s expand_aliases
  # shellcheck disable=SC2139
  alias bashunit_alias_ok='return 0'

  bashunit::run_command_or_eval "bashunit_alias_ok"

  assert_successful_code "$?"
  unalias bashunit_alias_ok
}

function test_run_command_or_eval_runs_alias_non_zero() {
  shopt -s expand_aliases
  # shellcheck disable=SC2139
  alias bashunit_alias_ko='return 3'

  bashunit::run_command_or_eval "bashunit_alias_ko"
  local exit_code=$?

  assert_same "3" "$exit_code"
  unalias bashunit_alias_ko
}

function test_run_command_or_eval_runs_function_not_treated_as_alias() {
  bashunit_fn_ok() { return 0; }

  bashunit::run_command_or_eval "bashunit_fn_ok"

  assert_successful_code "$?"
}

function test_run_command_or_eval_name_value_is_not_defined_as_alias() {
  # Regression: "name=value" must NOT be probed with `alias` (it would define
  # the alias and wrongly succeed). It has to be run directly and fail.
  bashunit::run_command_or_eval "bashunit_x=1"
  local exit_code=$?

  local side_effect="absent"
  if alias bashunit_x >/dev/null 2>&1; then
    side_effect="defined"
  fi

  assert_not_same "0" "$exit_code"
  assert_same "absent" "$side_effect"
}

function test_run_command_or_eval_multiword_command_is_not_treated_as_alias() {
  # A multi-word string can never be an alias name: run it directly.
  bashunit::run_command_or_eval "bashunit_missing_cmd --flag"
  local exit_code=$?

  assert_not_same "0" "$exit_code"
}

function test_unsuccessful_assert_true_on_function() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert true on function" \
    "command or function with zero exit code" \
    "but got " "exit code: 2")" \
    "$(assert_true "eval return 2")"
}

# @data_provider provider_successful_assert_false
function test_successful_assert_false() {
  # shellcheck disable=SC2086
  assert_empty "$(assert_false $1)"
}

function provider_successful_assert_false() {
  bashunit::data_set false
  bashunit::data_set "false"
  bashunit::data_set 1
}

function test_unsuccessful_assert_false() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert false" \
    "false or 1" \
    "but got " "true")" \
    "$(assert_false true)"
}

function test_unsuccessful_assert_false_with_empty_value() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert false with empty value" \
    "false or 1" \
    "but got " "")" \
    "$(assert_false "")"
}

function test_successful_assert_false_on_function() {
  assert_empty "$(assert_false "eval return 1")"
}

function test_unsuccessful_assert_false_on_function() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert false on function" \
    "command or function with non-zero exit code" \
    "but got " "exit code: 0")" \
    "$(assert_false "eval return 0")"
}

function test_successful_assert_same() {
  assert_empty "$(assert_same "1" "1")"
}

function test_unsuccessful_assert_same() {
  assert_same "$(bashunit::console_results::print_failed_test "Unsuccessful assert same" "1" "but got " "2")" \
    "$(assert_same "1" "2")"
}

function test_successful_assert_empty() {
  assert_empty "$(assert_empty "")"
}

function test_unsuccessful_assert_empty() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "Unsuccessful assert empty" "to be empty" "but got " "1")" \
    "$(assert_empty "1")"
}

function test_assert_same_with_custom_label() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "my custom label" "1" "but got " "2")" \
    "$(assert_same "1" "2" "my custom label")"
}

function test_assert_empty_with_custom_label() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "my custom label" "to be empty" "but got " "foo")" \
    "$(assert_empty "foo" "my custom label")"
}

function test_assert_not_empty_with_custom_label() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "my custom label" "to not be empty" "but got " "")" \
    "$(assert_not_empty "" "my custom label")"
}

function test_assert_not_same_with_custom_label() {
  assert_same \
    "$(bashunit::console_results::print_failed_test "my custom label" "foo" "to not be" "foo")" \
    "$(assert_not_same "foo" "foo" "my custom label")"
}
