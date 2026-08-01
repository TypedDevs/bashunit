#!/usr/bin/env bash

# Entry point for the src/assert/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
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
source "$BASHUNIT_ROOT_DIR/src/skip_todo.sh"
source "$BASHUNIT_ROOT_DIR/src/doubles/index.sh"
