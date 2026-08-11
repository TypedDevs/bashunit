#!/usr/bin/env bash

# Fixture for the conditional skip helpers. Every assertion placed after a
# helper that must skip is deliberately impossible: it fails the fixture run if
# the helper stopped marking the test but let the body continue.

function test_skip_if_true_stops_the_body() {
  bashunit::skip_if true "condition met"
  assert_same "unreachable" "reached"
}

function test_skip_if_false_runs_the_body() {
  bashunit::skip_if false "never used"
  assert_same "ok" "ok"
}

function test_skip_if_evaluates_a_compound_condition() {
  bashunit::skip_if "[ 1 -eq 1 ]" "compound condition met"
  assert_same "unreachable" "reached"
}

function test_skip_unless_runs_the_body_when_the_condition_holds() {
  bashunit::skip_unless true "never used"
  assert_same "ok" "ok"
}

function test_skip_unless_stops_the_body_when_the_condition_fails() {
  bashunit::skip_unless false "condition not met"
  assert_same "unreachable" "reached"
}

function test_skip_unless_command_missing() {
  bashunit::skip_unless_command definitely_not_a_command
  assert_same "unreachable" "reached"
}

function test_skip_unless_command_present() {
  bashunit::skip_unless_command bash
  assert_same "ok" "ok"
}

# @data_provider provide_two_values
function test_skip_if_inside_a_data_provider() {
  bashunit::skip_if true "provider skip"
  assert_same "unreachable" "$1"
}

function provide_two_values() {
  echo "a"
  echo "b"
}
