#!/usr/bin/env bash

# Entry point for the src/console/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# colors.sh first: it defines the _BASHUNIT_COLOR_* palette everything else
# renders with. The former results.sh is now six files, sourced leaves first:
# line/duration/diff have no console_results callees; test_line, deferred and
# summary build on them.
source "$BASHUNIT_ROOT_DIR/src/console/colors.sh"
source "$BASHUNIT_ROOT_DIR/src/console/header.sh"
source "$BASHUNIT_ROOT_DIR/src/console/line.sh"
source "$BASHUNIT_ROOT_DIR/src/console/duration.sh"
source "$BASHUNIT_ROOT_DIR/src/console/diff.sh"
source "$BASHUNIT_ROOT_DIR/src/console/test_line.sh"
source "$BASHUNIT_ROOT_DIR/src/console/deferred.sh"
source "$BASHUNIT_ROOT_DIR/src/console/summary.sh"
