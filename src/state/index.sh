#!/usr/bin/env bash

# Entry point for the src/state/ module: only `source` lines and comments belong
# here. build.sh emits a file's body before recursing into its `source` lines, so
# any statement here would run before its dependencies in the built binary
# (adrs/adr-010-src-module-directories.md).
#
# counters.sh and duplicates.sh declare the globals context.sh's per-test reset
# clears, so they are sourced first.
source "$BASHUNIT_ROOT_DIR/src/state/counters.sh"
source "$BASHUNIT_ROOT_DIR/src/state/duplicates.sh"
source "$BASHUNIT_ROOT_DIR/src/state/context.sh"
source "$BASHUNIT_ROOT_DIR/src/state/payload.sh"
source "$BASHUNIT_ROOT_DIR/src/state/parallel.sh"
