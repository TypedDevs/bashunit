#!/usr/bin/env bash

# Entry point for the src/reports/ module: only `source` lines and comments
# belong here. build.sh emits a file's body before recursing into its `source`
# lines, so any statement here would run before its dependencies in the built
# binary (adrs/adr-010-src-module-directories.md).
#
# collect.sh holds the shared result arrays; each writer reads them and nothing
# else, so the layering is one level deep.
source "$BASHUNIT_ROOT_DIR/src/reports/collect.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/junit.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/tap.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/json.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/gha.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/html.sh"
