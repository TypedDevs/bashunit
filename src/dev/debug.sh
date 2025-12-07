#!/usr/bin/env bash

# An alternative to echo when debugging.
# This is debug function; do not use in prod!
function dump() {
  printf "[%s] %s: %s\n" "${_BASHUNIT_COLOR_SKIPPED}DUMP${_BASHUNIT_COLOR_DEFAULT}" \
    "${_BASHUNIT_COLOR_PASSED}${BASH_SOURCE[1]}:${BASH_LINENO[0]}" \
    "${_BASHUNIT_COLOR_DEFAULT}$*"
}

# Dump and Die.
function dd() {
  printf "[%s] %s: %s\n" "${_BASHUNIT_COLOR_FAILED}DUMP${_BASHUNIT_COLOR_DEFAULT}" \
    "${_BASHUNIT_COLOR_PASSED}${BASH_SOURCE[1]}:${BASH_LINENO[0]}" \
    "${_BASHUNIT_COLOR_DEFAULT}$*"

  kill -9 $$
}
