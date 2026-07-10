#!/usr/bin/env bash

# Each test echoes an order marker so acceptance tests can read the dispatch
# order from the output independently of timing/formatting.
function test_alpha() {
  echo "ORDER:alpha"
  assert_same 1 1
}

function test_bravo() {
  echo "ORDER:bravo"
  assert_same 1 1
}

function test_charlie() {
  echo "ORDER:charlie"
  assert_same 1 1
}

function test_delta() {
  echo "ORDER:delta"
  assert_same 1 1
}

function test_echo() {
  echo "ORDER:echo"
  assert_same 1 1
}

function test_foxtrot() {
  echo "ORDER:foxtrot"
  assert_same 1 1
}

function test_golf() {
  echo "ORDER:golf"
  assert_same 1 1
}

function test_hotel() {
  echo "ORDER:hotel"
  assert_same 1 1
}
