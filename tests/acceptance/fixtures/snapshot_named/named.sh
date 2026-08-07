#!/usr/bin/env bash

function test_named_snapshots() {
  assert_match_snapshot "default value"
  assert_match_named_snapshot "first value" "named value"
  assert_match_named_snapshot "../../ second!" "safe value"
  assert_match_named_snapshot_ignore_colors "colored" $'\e[31mcolored value\e[0m'
}
