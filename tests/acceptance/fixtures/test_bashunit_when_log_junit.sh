#!/bin/bash

function test_success() {
  assert_same 1 1
}

function test_failure() {
  assert_same 2 3
}
