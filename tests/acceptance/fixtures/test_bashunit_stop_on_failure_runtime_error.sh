#!/usr/bin/env bash

function test_a_runtime_error() {
  nonexistent_command_bashunit_383_xyz
}

function test_b_not_executed() {
  assert_same 1 1
}
