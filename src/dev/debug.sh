#!/bin/bash

# An alternative to echo when debugging.
# This is debug function; do not use in prod!
function dump() {
  printf "[%s] %s: %s\n" "${_COLOR_SKIPPED}DUMP${_COLOR_DEFAULT}" \
    "${_COLOR_PASSED}${BASH_SOURCE[1]}:${BASH_LINENO[0]}" \
    "${_COLOR_DEFAULT}$*"
}

# Dump and Die.
function dd() {
  printf "[%s] %s: %s\n" "${_COLOR_FAILED}DUMP${_COLOR_DEFAULT}" \
    "${_COLOR_PASSED}${BASH_SOURCE[1]}:${BASH_LINENO[0]}" \
    "${_COLOR_DEFAULT}$*"

  kill -9 $$
}
