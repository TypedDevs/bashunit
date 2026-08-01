#!/usr/bin/env bash

# Entry point for the src/assert/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# core.sh first: the other files call its shared helpers (assert::should_skip,
# assert::fail_with, assert::join_to_slot).
source "$BASHUNIT_ROOT_DIR/src/assert/core.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/arrays.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/assertions.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/once.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/dates.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/duration.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/files.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/folders.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/json.sh"
source "$BASHUNIT_ROOT_DIR/src/assert/snapshot.sh"

# Not assertions, but part of the same public test surface the runner loads.
# skip_todo moved to src/api/ in #949, where the rest of that surface lives.
source "$BASHUNIT_ROOT_DIR/src/doubles/index.sh"
