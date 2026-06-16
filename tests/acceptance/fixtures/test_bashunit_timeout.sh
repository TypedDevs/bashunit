#!/usr/bin/env bash

function test_passes_quickly() {
  assert_same "ok" "ok"
}

function test_hangs_until_killed() {
  sleep 30
  assert_same "never" "reached"
}
