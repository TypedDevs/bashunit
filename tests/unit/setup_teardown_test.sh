#!/usr/bin/env bash

TEST_COUNTER=1

function set_up_before_script() {
  TEST_COUNTER=$(( TEST_COUNTER + 1 ))
}

function set_up() {
  TEST_COUNTER=$(( TEST_COUNTER + 1 ))
}

function tear_down() {
  TEST_COUNTER=$(( TEST_COUNTER - 1 ))
}

function tear_down_after_script() {
  TEST_COUNTER=$(( TEST_COUNTER - 1 ))
}

function test_counter_is_incremented_after_setup_before_script_and_setup() {
  assert_same "3" "$TEST_COUNTER"
}

function test_counter_is_decremented_and_incremented_after_teardown_and_setup() {
  assert_same "3" "$TEST_COUNTER"
}
