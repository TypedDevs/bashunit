#!/usr/bin/env bash

# Each test appends its name to an order file, so acceptance tests can read the
# dispatch order from the filesystem instead of parsing console output (which
# varies with color, output mode, TTY and locale).
function record_order() {
  printf '%s\n' "$1" >>"${BASHUNIT_TEST_ORDER_FILE:?order file required}"
}

function test_alpha() {
  record_order alpha
  assert_same 1 1
}

function test_bravo() {
  record_order bravo
  assert_same 1 1
}

function test_charlie() {
  record_order charlie
  assert_same 1 1
}

function test_delta() {
  record_order delta
  assert_same 1 1
}

function test_echo() {
  record_order echo
  assert_same 1 1
}

function test_foxtrot() {
  record_order foxtrot
  assert_same 1 1
}

function test_golf() {
  record_order golf
  assert_same 1 1
}

function test_hotel() {
  record_order hotel
  assert_same 1 1
}
