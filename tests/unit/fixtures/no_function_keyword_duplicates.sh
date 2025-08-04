#!/usr/bin/env bash
# shellcheck disable=SC2317
# shellcheck disable=SC2329

test_func1() {
  echo "Function 1"
}

test_func2() {
  echo "Function 2"
}

test_func3() {
  echo "Function 3"
}

test_func2() {
  echo "Function 2 Duplicate"
}
