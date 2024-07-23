#!/bin/bash

function test_a() {
  assert_equals 1 1
}

function test_b() {
  assert_equals 1 1
  assert_equals 1 1
}

function test_c() {
  assert_equals 1 1
  assert_equals 1 2
  assert_equals 1 1
}
