#!/usr/bin/env bash

function test_bootstrap_arg1_is_available() {
  assert_equals "hello" "$BOOTSTRAP_ARG1"
}

function test_bootstrap_arg2_is_available() {
  assert_equals "world" "$BOOTSTRAP_ARG2"
}

function test_all_bootstrap_args_are_available() {
  assert_equals "hello world" "$BOOTSTRAP_ALL_ARGS"
}
