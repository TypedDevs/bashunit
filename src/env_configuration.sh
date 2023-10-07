#!/bin/bash

set -o allexport
# shellcheck source=/dev/null
[[ -f ".env" ]] && source .env set
set +o allexport

if [[ -z "$PARALLEL_RUN" ]]; then
  PARALLEL_RUN=$_DEFAULT_PARALLEL_RUN
fi

if [[ -z "$SHOW_HEADER" ]]; then
  SHOW_HEADER=$_DEFAULT_SHOW_HEADER
fi

if [[ -z "$HEADER_ASCII_ART" ]]; then
  HEADER_ASCII_ART=$_DEFAULT_HEADER_ASCII_ART
fi

if [[ -z "$SIMPLE_OUTPUT" ]]; then
  SIMPLE_OUTPUT=$_DEFAULT_SIMPLE_OUTPUT
fi
