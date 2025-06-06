#!/usr/bin/env bash
set -euo pipefail

function test_asserting_foo_strings() {
  assert_same "foo" "foo"
}
