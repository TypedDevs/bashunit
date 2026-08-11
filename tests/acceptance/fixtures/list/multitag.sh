#!/usr/bin/env bash

# A tag may contain spaces, so tags are joined and split on commas only.
# @tags fileTag

# @tag slow
function test_multitag_slow() {
  assert_true true
}

# @tag needs a db
function test_multitag_spaced_tag() {
  assert_true true
}
