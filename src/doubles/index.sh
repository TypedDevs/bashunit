#!/usr/bin/env bash

# Entry point for the src/doubles/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# mock.sh first: it declares _BASHUNIT_MOCKED_FUNCTIONS, the registry that
# bashunit::spy also registers into and that runner/hooks.sh unwinds per test.
source "$BASHUNIT_ROOT_DIR/src/doubles/mock.sh"
source "$BASHUNIT_ROOT_DIR/src/doubles/spy.sh"
source "$BASHUNIT_ROOT_DIR/src/doubles/assertions.sh"
