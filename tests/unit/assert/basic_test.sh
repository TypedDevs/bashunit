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

  local exit_code=0
  bashunit::run_command_or_eval "bashunit_alias_ko" || exit_code=$?

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
  local exit_code=0
  bashunit::run_command_or_eval "bashunit_x=1" || exit_code=$?

  local side_effect="absent"
  if alias bashunit_x >/dev/null 2>&1; then
    side_effect="defined"
  fi

  assert_not_same "0" "$exit_code"
  assert_same "absent" "$side_effect"
}

function test_run_command_or_eval_multiword_command_is_not_treated_as_alias() {
  # A multi-word string can never be an alias name: run it directly.
  local exit_code=0
  bashunit::run_command_or_eval "bashunit_missing_cmd --flag" || exit_code=$?

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

# Exit code 127 is the shell's not-found code. Reporting the bare number
# gives the reader nothing to act on -- and the most natural shell idiom,
# a `[ ... ]` test expression, produces exactly this because assert_true runs
# its argument as a command word rather than evaluating it.
function test_assert_true_reports_a_missing_command_by_name() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert true reports a missing command by name" \
      "command or function with zero exit code" "but got " \
      "unknown command: definitely_not_a_command")" \
    "$(assert_true "definitely_not_a_command")"
}

function test_assert_true_reports_a_bracket_expression_as_not_found() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert true reports a bracket expression as not found" \
      "command or function with zero exit code" "but got " \
      "unknown command: [ -d /tmp ]")" \
    "$(assert_true "[ -d /tmp ]")"
}

# assert_false only failed when the exit code was 0, so a command that does not
# exist satisfied it: 127 is non-zero, therefore "false". A typo in the command
# name made the assertion pass while testing nothing.
function test_assert_false_fails_when_the_command_does_not_exist() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert false fails when the command does not exist" \
      "command or function with non-zero exit code" "but got " \
      "unknown command: definitely_not_a_command")" \
    "$(assert_false "definitely_not_a_command")"
}

# Arguments as real arguments. The single-argument forms are untouched: one
# argument still means "run this as a command word", so every existing call
# behaves exactly as before.
function test_assert_true_accepts_a_command_with_arguments() {
  assert_empty "$(assert_true test -d /tmp)"
}

function test_assert_true_variadic_fails_when_the_command_fails() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert true variadic fails when the command fails" \
      "command or function with zero exit code" "but got " \
      "exit code: 1")" \
    "$(assert_true test -d /definitely/not/a/directory)"
}

function test_assert_false_accepts_a_command_with_arguments() {
  assert_empty "$(assert_false test -d /definitely/not/a/directory)"
}

function test_assert_true_variadic_does_not_re_parse_its_arguments() {
  local dir
  dir=$(bashunit::temp_dir)
  # A path containing a space survives, because it is passed as one argument
  # rather than re-split out of a single string.
  mkdir -p "$dir/two words"

  assert_empty "$(assert_true test -d "$dir/two words")"
}

function test_assert_true_variadic_reports_a_missing_command() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Assert true variadic reports a missing command" \
      "command or function with zero exit code" "but got " \
      "unknown command: definitely_not_a_command --flag")" \
    "$(assert_true definitely_not_a_command --flag)"
}
