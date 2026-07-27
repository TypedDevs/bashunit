#!/usr/bin/env bash

function test_snapshot_without_colors() {
  assert_match_snapshot_ignore_colors "plain value"
}
