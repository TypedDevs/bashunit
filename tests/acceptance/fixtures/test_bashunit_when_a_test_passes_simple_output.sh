#!/bin/bash

function test_1() {
  assert_equals "1" "1"
}

function test_2() {
  assert_equals "1" "1"
  assert_equals "1" "1"
}

function test_3() {
  assert_equals "1" "1"
  assert_equals "1" "1"
}

function test_4() {
  assert_equals "1" "1"
}
