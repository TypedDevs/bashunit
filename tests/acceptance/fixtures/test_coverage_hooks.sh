#!/usr/bin/env bash

# This fixture exercises coverage attribution inside lifecycle hooks.
# The set_up hook calls src/ functions; coverage should track those lines.

function set_up() {
  local f
  f="$(bashunit::temp_file "cov-hooks")"
  if [ -n "${f:-}" ]; then
    echo "tmp created" > /dev/null
  fi
}

function test_noop() {
  # No-op test; coverage should still attribute lines from set_up
  assert_true true
}
