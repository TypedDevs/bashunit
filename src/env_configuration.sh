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

if [[ -z "$STOP_ON_FAILURE" ]]; then
  STOP_ON_FAILURE=$_DEFAULT_STOP_ON_FAILURE
fi

if [[ -z "$SHOW_EXECUTION_TIME" ]]; then
  SHOW_EXECUTION_TIME=$_DEFAULT_SHOW_EXECUTION_TIME
fi

if [[ -z "$DEFAULT_PATH" ]]; then
  DEFAULT_PATH=$_DEFAULT_DEFAULT_PATH
fi

if [[ -z "$LOG_JUNIT" ]]; then
  LOG_JUNIT=$_DEFAULT_LOG_JUNIT
fi
