#!/usr/bin/env bash

function test_good() {
  assert_equals 1 1
}

function test_with_syntax_error() {
  if [ 1 -eq 1 ]
    echo "missing then keyword"
  fi
}

function test_another() {
  assert_equals 2 2
}
