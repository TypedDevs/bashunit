#!/usr/bin/env bash

# Entry point for the src/doubles/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# mock.sh first: it declares _BASHUNIT_MOCKED_FUNCTIONS, the registry that
# bashunit::spy also registers into and that runner/hooks.sh unwinds per test.
source "$BASHUNIT_ROOT_DIR/src/doubles/mock.sh"
source "$BASHUNIT_ROOT_DIR/src/doubles/spy.sh"
source "$BASHUNIT_ROOT_DIR/src/doubles/assertions.sh"
