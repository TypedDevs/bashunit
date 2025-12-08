#!/usr/bin/env bash

# Bootstrap file that receives arguments and exports them for tests
export BOOTSTRAP_ARG1="${1:-}"
export BOOTSTRAP_ARG2="${2:-}"
export BOOTSTRAP_ALL_ARGS="$*"
