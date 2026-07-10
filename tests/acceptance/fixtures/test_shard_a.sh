#!/usr/bin/env bash

function test_shard_a() {
  printf '%s\n' a >>"${BASHUNIT_TEST_ORDER_FILE:?order file required}"
  assert_same 1 1
}
