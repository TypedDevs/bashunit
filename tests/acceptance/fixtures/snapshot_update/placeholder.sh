#!/usr/bin/env bash

function test_snapshot_with_placeholder() {
  assert_match_snapshot "run at 12:00:00"
}
