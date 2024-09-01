#!/bin/bash

function test_dump() {
  assert_equals \
    "[DUMP] tests/unit/debug_test.sh:6: hi, debugging"\
    "$(dump "hi, debugging")"
}
