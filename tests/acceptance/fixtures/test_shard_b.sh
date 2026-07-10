#!/usr/bin/env bash

function test_shard_b() {
  printf '%s\n' b >>"${BASHUNIT_TEST_ORDER_FILE:?order file required}"
  assert_same 1 1
}
