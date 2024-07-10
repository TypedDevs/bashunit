#!/bin/bash

function test_success() {
  assert_equals 1 1
}

function test_failure() {
  assert_equals 2 3
}
