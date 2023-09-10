#!/bin/bash

set -o allexport
# shellcheck source=/dev/null
[[ -f ".env" ]] && source .env set
set +o allexport

if [ -z "$PARALLEL_RUN" ]; then
  PARALLEL_RUN=_DEFAULT_PARALLEL_RUN
fi
