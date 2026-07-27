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
