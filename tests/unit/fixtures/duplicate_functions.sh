#!/usr/bin/env bash

# shellcheck disable=SC2317
function func1() {
  echo "Function 1"
}

function func2() {
  echo "Function 2"
}

function func1() {
  echo "Function 1 Duplicate but not test"
}

function func3() {
  echo "Function 3"
}

function func2() {
  echo "Function 2 Duplicate but not test"
}

function test_func() {
  echo "Function Duplicate"
}

function test_func() {
  echo "Function Duplicate"
}
