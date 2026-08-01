#!/usr/bin/env bash

# Entry point for the src/console/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# colors.sh first: it defines the _BASHUNIT_COLOR_* palette that header.sh and
# results.sh render with. Order matches the entrypoint's before this module
# existed.
source "$BASHUNIT_ROOT_DIR/src/console/colors.sh"
source "$BASHUNIT_ROOT_DIR/src/console/header.sh"
source "$BASHUNIT_ROOT_DIR/src/console/results.sh"
