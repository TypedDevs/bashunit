#!/usr/bin/env bash
set -euo pipefail

# First unit tests for src/main.sh: pin set_shard_or_exit's validation, which
# guards --shard's slice arithmetic against off-by-one specs. It exits the
# shell on invalid input, so every call runs inside a subshell.

function _shard_status() {
  (
    bashunit::main::set_shard_or_exit "$1" >/dev/null 2>&1
    echo "ok $BASHUNIT_SHARD_INDEX/$BASHUNIT_SHARD_TOTAL"
  ) 2>/dev/null || echo "rejected"
}

function test_shard_spec_accepts_the_full_range_boundaries() {
  assert_same "ok 1/4" "$(_shard_status 1/4)"
  assert_same "ok 4/4" "$(_shard_status 4/4)"
  assert_same "ok 1/1" "$(_shard_status 1/1)"
}

function test_shard_spec_rejects_index_zero() {
  assert_same "rejected" "$(_shard_status 0/4)"
}

function test_shard_spec_rejects_total_zero() {
  assert_same "rejected" "$(_shard_status 1/0)"
}

function test_shard_spec_rejects_missing_slash() {
  assert_same "rejected" "$(_shard_status 3)"
}

function test_shard_spec_rejects_empty_and_partial_specs() {
  assert_same "rejected" "$(_shard_status "")"
  assert_same "rejected" "$(_shard_status "/4")"
  assert_same "rejected" "$(_shard_status "2/")"
}

function test_shard_spec_rejects_negative_and_decorated_numbers() {
  assert_same "rejected" "$(_shard_status "-1/4")"
  assert_same "rejected" "$(_shard_status "1/+4")"
  assert_same "rejected" "$(_shard_status "1.5/4")"
}
