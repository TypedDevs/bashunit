#!/usr/bin/env bash

# This fixture exercises coverage attribution inside lifecycle hooks.

function set_up() {
    # Invoke src functions to generate attributable coverage hits
    local f
    f="$(bashunit::temp_file \"cov-hooks\")"
    [[ -n "${f:-}" ]] && echo "tmp created" > /dev/null
}

function test_noop() {
    # No-op test; coverage should still attribute lines from set_up
    assert_true true
}
