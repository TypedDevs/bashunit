#!/usr/bin/env bash

function test_beta_one() {
  assert_same 3 3
}

# Defined last on purpose: --order-by defects has to move it to the front on the
# next run, which is what the ordering assertions measure.
function test_beta_fails() {
  assert_same "expected" "actual"
}
