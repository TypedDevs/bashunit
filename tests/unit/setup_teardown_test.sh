#!/bin/bash

TEST_COUNTER=1

function setUpBeforeScript() {
  TEST_COUNTER=$(( TEST_COUNTER + 1 ))
}

function setUp() {
  TEST_COUNTER=$(( TEST_COUNTER + 1 ))
}

function tearDown() {
  TEST_COUNTER=$(( TEST_COUNTER - 1 ))
}

function tearDownAfterScript() {
  TEST_COUNTER=$(( TEST_COUNTER - 1 ))
}

function test_counter_is_incremented_after_setup_before_script_and_setup() {
  assertEquals "3" "$TEST_COUNTER"
}

function test_counter_is_decremented_and_incremented_after_teardown_and_setup() {
  assertEquals "3" "$TEST_COUNTER"
}

