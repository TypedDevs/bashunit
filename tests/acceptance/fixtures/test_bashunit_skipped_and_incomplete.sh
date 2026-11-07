#!/usr/bin/env bash

function test_passes() {
  assert_true true
}

function test_skips_on_purpose() {
  bashunit::skip "not this time" && return
}

function test_is_not_done_yet() {
  bashunit::todo "write the assertion"
}
