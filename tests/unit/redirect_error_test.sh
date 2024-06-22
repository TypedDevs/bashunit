#!/bin/bash

function test_redirect_error() {
  local result
  result="$(my_help)"
  assert_equals "BASH_SOURCE: redirect_error_test.sh" "$result"
  assert_successful_code
}

function my_help() {
  smth "BASH_SOURCE: ${BASH_SOURCE[0]}"
  exit 1
}

function smth(){
  echo "$*" >&2
}
