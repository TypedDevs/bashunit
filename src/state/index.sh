#!/usr/bin/env bash

# Entry point for the src/state/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# counters.sh and duplicates.sh declare the globals context.sh's per-test reset
# clears, so they are sourced first.
source "$BASHUNIT_ROOT_DIR/src/state/counters.sh"
source "$BASHUNIT_ROOT_DIR/src/state/duplicates.sh"
source "$BASHUNIT_ROOT_DIR/src/state/context.sh"
source "$BASHUNIT_ROOT_DIR/src/state/payload.sh"
source "$BASHUNIT_ROOT_DIR/src/state/parallel.sh"
