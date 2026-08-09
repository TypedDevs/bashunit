#!/usr/bin/env bash

# Each test appends its own name to $LIST_ORDER_LOG, so the execution order can
# be compared against --list without parsing rendered output (which varies with
# locale and sed dialect).

function _record() {
  printf '%s\n' "$1" >>"${LIST_ORDER_LOG:?}"
}

function test_order_one() {
  _record test_order_one
  assert_true true
}

function test_order_two() {
  _record test_order_two
  assert_true true
}

function test_order_three() {
  _record test_order_three
  assert_true true
}

function test_order_four() {
  _record test_order_four
  assert_true true
}
