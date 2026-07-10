#!/usr/bin/env bash

function test_shard_d() {
  printf '%s\n' d >>"${BASHUNIT_TEST_ORDER_FILE:?order file required}"
  assert_same 1 1
}
