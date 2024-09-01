#!/bin/bash

function test_success() {
  assert_same 1 1
}

function test_fail() {
  assert_empty "non empty"
}

function test_skipped() {
  skip
}

function test_todo() {
  todo
}
