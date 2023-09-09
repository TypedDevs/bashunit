#!/bin/bash

set -o allexport
source .env set
set +o allexport

if [[ -z "$PARALLEL_RUN" ]]; then
  PARALLEL_RUN=true
fi
