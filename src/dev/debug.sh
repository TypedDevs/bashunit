#!/bin/bash

# An alternative to echo when debugging.
# This is debug function; do not use in prod!
function dump() {
  echo "[DEBUG] ${BASH_SOURCE[1]}:${BASH_LINENO[0]}:" "$@"
  set -x # enable bash debug, to have a deeper context
}

# Dump and Die.
function dd() {
  dump "$@"
  exit 1
}
