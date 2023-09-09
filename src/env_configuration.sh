#!/bin/bash

set -o allexport
# shellcheck source=/dev/null
source .env set
set +o allexport

if [ -z "$PARALLEL_RUN" ]; then
  PARALLEL_RUN=false
fi
