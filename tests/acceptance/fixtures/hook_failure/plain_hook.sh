#!/usr/bin/env bash

# The hook fails with a plain failing command (ERR-trap path).
function set_up_before_script() {
  command -v definitely_missing_tool_bashunit >/dev/null 2>&1
}

function test_plain_one() { assert_true true; }
function test_plain_two() { assert_true true; }
