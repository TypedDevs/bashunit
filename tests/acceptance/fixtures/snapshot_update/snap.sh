#!/usr/bin/env bash

function test_snapshot_alpha() {
  assert_match_snapshot "alpha value"
}

function test_snapshot_beta() {
  assert_match_snapshot "beta value"
}
