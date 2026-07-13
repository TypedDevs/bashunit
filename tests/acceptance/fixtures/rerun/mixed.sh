#!/usr/bin/env bash

function test_rerun_alpha_passes() {
  assert_same 1 1
}

function test_rerun_beta_fails() {
  assert_same "expected" "actual"
}

function test_rerun_gamma_passes() {
  assert_same 2 2
}
