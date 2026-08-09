#!/usr/bin/env bash

# @tags integration db

function test_inherits_file_tags() {
  assert_same 1 1
}

# @tag slow
function test_inherits_and_adds() {
  assert_same 2 2
}
