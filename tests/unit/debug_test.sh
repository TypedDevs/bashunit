#!/bin/bash

function test_dump() {
  assert_equals_ignore_colors \
    "[DUMP] tests/unit/debug_test.sh:6: hi, debugging"\
    "$(dump "hi, debugging")"
}
