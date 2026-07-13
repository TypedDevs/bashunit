#!/usr/bin/env bash

function test_rerun_all_pass_one() {
  assert_same 1 1
}

function test_rerun_all_pass_two() {
  assert_same 2 2
}
