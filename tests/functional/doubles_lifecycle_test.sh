#!/bin/bash

# Pins the lifecycle documented in docs/test-doubles.md: doubles declared in
# set_up_before_script live for the whole file, doubles declared inside a test
# die with it, and bashunit::unmock reaches no further than the current test.

function set_up_before_script() {
  bashunit::mock lifecycle_shared_double echo "from before script"
}

function test_a_before_script_double_is_visible_in_a_test() {
  assert_same "from before script" "$(lifecycle_shared_double)"
}

function test_b_unmock_only_affects_the_current_test() {
  bashunit::unmock lifecycle_shared_double

  assert_empty "$(lifecycle_shared_double 2>/dev/null || true)"
}

function test_c_before_script_double_survives_the_unmock_of_another_test() {
  assert_same "from before script" "$(lifecycle_shared_double)"
}

function test_d_a_double_declared_in_a_test_does_not_leak() {
  bashunit::mock lifecycle_local_double echo "local"

  assert_same "local" "$(lifecycle_local_double)"
}

function test_e_the_previous_test_double_is_gone() {
  assert_empty "$(lifecycle_local_double 2>/dev/null || true)"
}

function test_unmock_restores_the_real_command() {
  bashunit::mock ls echo "mocked"
  assert_same "mocked" "$(ls)"

  bashunit::unmock ls

  assert_not_same "mocked" "$(ls)"
}

function provide_function_double_types() {
  bashunit::data_set spy
  bashunit::data_set mock
  bashunit::data_set mock_sequence
}

# @data_provider provide_function_double_types
function test_unmock_restores_the_original_shell_function() {
  function lifecycle_original_function() { printf 'original %s\n' "$1"; }
  if [ "$1" = spy ]; then
    bashunit::spy lifecycle_original_function
  else
    "bashunit::$1" lifecycle_original_function 'echo doubled'
  fi

  bashunit::unmock lifecycle_original_function

  assert_same 'original argument' "$(lifecycle_original_function argument 2>&1)"
}

function test_unmock_restores_the_first_original_after_replacing_a_double() {
  function lifecycle_replaced_function() { printf 'original\n'; }
  bashunit::spy lifecycle_replaced_function
  bashunit::mock lifecycle_replaced_function echo doubled
  bashunit::mock_sequence lifecycle_replaced_function 'echo sequenced'

  bashunit::unmock lifecycle_replaced_function
  bashunit::unmock lifecycle_replaced_function

  assert_same original "$(lifecycle_replaced_function 2>&1)"
}

function test_unmock_removes_repeated_doubles_of_an_undefined_command() {
  bashunit::mock lifecycle_undefined_function echo first
  bashunit::mock lifecycle_undefined_function echo second

  bashunit::unmock lifecycle_undefined_function

  assert_empty "$(declare -F lifecycle_undefined_function)"
}

function test_unmock_preserves_an_exported_shell_function() {
  # shellcheck disable=SC2329 # Invoked by a child Bash.
  function lifecycle_exported_function() { printf original; }
  export -f lifecycle_exported_function
  if [ "$(bash -c lifecycle_exported_function 2>/dev/null)" != original ]; then
    bashunit::skip 'this shell does not import exported functions'
    return
  fi
  bashunit::spy lifecycle_exported_function

  bashunit::unmock lifecycle_exported_function

  assert_same original "$(bash -c lifecycle_exported_function 2>/dev/null)"
}

function test_unmock_forgets_the_calls_recorded_so_far() {
  bashunit::spy lifecycle_spy
  lifecycle_spy once
  bashunit::unmock lifecycle_spy

  bashunit::spy lifecycle_spy

  assert_empty "$(assert_not_called lifecycle_spy 2>&1)"
}

function test_unmock_of_an_unknown_name_is_a_no_op() {
  bashunit::unmock lifecycle_never_mocked

  assert_successful_code "$?"
}
