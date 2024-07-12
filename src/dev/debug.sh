#!/bin/bash

# An alternative to echo when debugging.
# This is debug function; do not use in prod!
function dump() {
  echo "[DEBUG] ${BASH_SOURCE[1]}:${BASH_LINENO[0]}:" "$@"
}

# Dump and Die.
function dd() {
  dump "$@"
  exit 1
}
