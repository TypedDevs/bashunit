#!/usr/bin/env bash

function test_hits_a_real_shell_error() {
  definitely_not_a_real_command_xyz
  assert_same 1 1
}
