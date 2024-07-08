#!/bin/bash

function assert_foo() {
  local actual="$1"
  local expected="foo"

  if [[ "$expected" != "$actual" ]]; then
    bashunit::assertion_failed "$expected" "${actual}"
    return
  fi

  bashunit::assertion_passed
}

function assert_positive_number() {
  local actual="$1"

  if [[ "$actual" -le 0 ]]; then
    bashunit::assertion_failed "positive number" "${actual}" "got"
    return
  fi

  bashunit::assertion_passed
}
