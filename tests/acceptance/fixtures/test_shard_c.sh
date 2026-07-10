#!/usr/bin/env bash

function test_shard_c() {
  printf '%s\n' c >>"${BASHUNIT_TEST_ORDER_FILE:?order file required}"
  assert_same 1 1
}
