#!/usr/bin/env bash

function assert_foo() {
  local actual="$1"
  local expected="foo"

  if [ "$expected" != "$actual" ]; then
    bashunit::assertion_failed "$expected" "${actual}"
    return
  fi

  bashunit::assertion_passed
}

function assert_positive_number() {
  local actual="$1"

  if [ "$actual" -le 0 ]; then
    bashunit::assertion_failed "positive number" "${actual}" "got"
    return
  fi

  bashunit::assertion_passed
}

# Same check as assert_positive_number, written with the one-call helper.
function assert_that_positive_number() {
  bashunit::assert_that "positive number" "$1" test "$1" -gt 0
}

# Names itself in its own failure block via the optional label argument.
function assert_labelled_foo() {
  local actual="$1"

  if [ "foo" != "$actual" ]; then
    bashunit::assertion_failed "foo" "${actual}" "but got " "Assert labelled foo"
    return
  fi

  bashunit::assertion_passed
}
